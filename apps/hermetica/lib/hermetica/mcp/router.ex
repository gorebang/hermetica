# lib/hermetica/mcp/router.ex
defmodule Hermetica.MCP.Router do
  @moduledoc false

  alias Hermetica.FlowRegistry
  alias Hermetica.MCP.{Transport, Util, Validate}
  alias Hermetica.Runs

  # Entry point: handle 1 JSON-RPC request map; may call Transport to stream partials.
  def handle(%{"jsonrpc" => "2.0", "method" => method, "id" => id} = req, io) do
    result =
      case method do
        "initialize"      -> initialize()
        "ping"            -> %{"ok" => true}
        "tools/list"      -> tools_list()
        "tools/call"      -> tools_call(req["params"] || %{}, id, io)
        "resources/list"  -> resources_list()
        "resources/read"  -> resources_read(req["params"] || %{})
        "prompts/list"    -> prompts_list()
        "prompts/get"     -> prompts_get(req["params"] || %{})
        _ ->
          {:error, %{code: -32601, message: "Method not found: #{method}"}}
      end

    Util.wrap_jsonrpc(id, result)
  end

  def handle(_bad, _io) do
    %{
      "jsonrpc" => "2.0",
      "id" => nil,
      "error" => %{"code" => -32600, "message" => "Invalid Request"}
    }
  end

  # ---- Capabilities ----
  defp initialize do
    %{
      "protocolVersion" => "2025-06-18",
      "capabilities" => %{
        "tools" => %{"list" => true, "call" => true},
        "resources" => %{"list" => true, "read" => true},
        "prompts" => %{"list" => true, "get" => true}
      }
    }
  end

  # ---- Tools ----
  defp tools_list do
    tools = FlowRegistry.all() |> Enum.map(&FlowRegistry.to_tool/1)
    if tools == [], do: IO.warn(":hermetica :flows is empty — add Hermetica.Flows.* to config")
    %{"tools" => tools}
  end

  defp tools_call(%{"name" => full, "arguments" => args} = params, id, io) do
    try do
      with "flows." <> flow_name <- full,
           mod when not is_nil(mod) <- FlowRegistry.by_name(flow_name) do
        # 1) Validate required arguments (minimal, no deps)
        schema = mod.schema()
        Validate.ensure_required!(schema, args)

        # 2) Meta + run id
        meta   = Map.get(params, "meta", %{})
        run_id = "run_#{:erlang.unique_integer([:positive])}"

        # 3) Structured partials
emit_fn = fn {:stage, stage, data} ->
  payload = %{
    "content"  => [%{"type" => "text", "text" => "[#{stage}] " <> Jason.encode!(data)}],
    "metadata" => %{"event" => "stage", "stage" => stage, "data" => data, "run_id" => run_id, "meta" => meta}
  }
  Transport.send_partial(io, id, payload)
end


        # 4) Execute with timeout (simple Task; no extra supervisors required)
        ctx = %{run_id: run_id, emit: emit_fn, meta: meta}

        case call_with_timeout(mod, args, ctx) do
          {:ok, result} ->
            result1 = Map.put(result, :status, "ok")

            # Persist if Runs module is available
            if Code.ensure_loaded?(Runs) and function_exported?(Runs, :save!, 2) do
              Runs.save!(run_id, result1)
            end

            %{
              "content" => [
                %{
                  "type" => "text",
                  "mimeType" => "application/json",
                  "text" => Jason.encode!(result1)
                }
              ]
            }

          {:error, err} ->
            {:error, normalize_error(err)}
        end
      else
        _ ->
          {:error, %{code: -32602, message: "Unknown tool #{inspect(full)}"}}
      end
    rescue
      e in [ArgumentError] ->
        {:error, %{code: -32602, message: Exception.message(e)}}
    end
  end

  # Run a flow with a timeout using Task.async/yield (keeps deps at zero)
  defp call_with_timeout(mod, args, ctx) do
    timeout = Map.get(args, "timeout_ms", 60_000)
    task = Task.async(fn -> mod.run(args, ctx) end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, result}} -> {:ok, result}
      {:ok, {:error, err}} -> {:error, err}
      nil                  -> {:error, %{code: 1002, message: "Run timed out after #{timeout}ms"}}
      {:exit, reason}      -> {:error, %{code: 1001, message: "Run crashed", data: inspect(reason)}}
      other                -> {:error, %{code: 1000, message: "Unexpected task reply", data: inspect(other)}}
    end
  end

  defp normalize_error(%{code: _c, message: _m} = err), do: err
  defp normalize_error(msg) when is_binary(msg), do: %{code: 1000, message: msg}
  defp normalize_error(other), do: %{code: 1000, message: "Flow error", data: other}

  # ---- Resources (uses Hermetica.Runs if present) ----
  defp resources_list do
    cond do
      Code.ensure_loaded?(Runs) and function_exported?(Runs, :list_ids, 0) ->
        runs =
          for id <- Runs.list_ids() do
            %{"uri" => "hermetica://runs/#{id}", "name" => "Run #{id}", "mimeType" => "application/json"}
          end

        %{"resources" => runs}

      true ->
        %{"resources" => []}
    end
  end

  defp resources_read(%{"uri" => "hermetica://runs/" <> id}) do
    cond do
      Code.ensure_loaded?(Runs) and function_exported?(Runs, :load!, 1) ->
        body = Runs.load!(id)
        %{
          "contents" => [
            %{"type" => "text", "mimeType" => "application/json", "text" => Jason.encode!(body)}
          ]
        }

      true ->
        {:error, %{code: -32602, message: "Unknown resource (no persistence wired)"}}
    end
  end

  defp resources_read(_), do: {:error, %{code: -32602, message: "Unknown resource"}}

  # ---- Prompts (optional) ----
  defp prompts_list do
    %{
      "prompts" => [
        %{
          "name" => "debug-run",
          "description" => "Analyze a failing Hermetica run",
          "arguments" => [%{"name" => "run_id", "required" => true}]
        }
      ]
    }
  end

  defp prompts_get(%{"name" => "debug-run", "arguments" => %{"run_id" => id}}) do
    %{
      "description" => "Help debug a Hermetica run",
      "messages" => [
        %{
          "role" => "user",
          "content" => %{
            "type" => "text",
            "text" =>
              "Please analyze Hermetica run #{id}, identify failing steps, and propose a minimal repro."
          }
        }
      ]
    }
  end

  defp prompts_get(_), do: {:error, %{code: -32602, message: "Unknown prompt/args"}}
end
