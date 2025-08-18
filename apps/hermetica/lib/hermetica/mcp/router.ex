# lib/hermetica/mcp/router.ex
defmodule Hermetica.MCP.Router do
  @moduledoc false
  alias Hermetica.{FlowRegistry}
  alias Hermetica.MCP.{Transport, Util}

  # Entry point: handle 1 JSON-RPC request map; may call Transport to stream partials.
  def handle(%{"jsonrpc" => "2.0", "method" => method, "id" => id} = req, io) do
    result =
      case method do
        "initialize"      -> initialize()
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
    %{"jsonrpc" => "2.0", "id" => nil, "error" => %{"code" => -32600, "message" => "Invalid Request"}}
  end

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

  defp tools_list do
    tools = FlowRegistry.all() |> Enum.map(&FlowRegistry.to_tool/1)
    %{"tools" => tools}
  end

  defp tools_call(%{"name" => full, "arguments" => args} = params, id, io) do
    with "flows." <> flow_name <- full,
         mod when not is_nil(mod) <- FlowRegistry.by_name(flow_name) do
      run_id = "run_#{:erlang.unique_integer([:positive])}"


      emit_fn = fn event ->
        # Convert your internal events into MCP tools/partial
        payload = case event do
          {:stage, stage, data} ->
            %{"content" => [%{"type" => "text", "text" => "[#{stage}] " <> Jason.encode!(data)}]}
          other ->
            %{"content" => [%{"type" => "text", "text" => Jason.encode!(other)}]}
        end

        Transport.send_partial(io, id, payload)
      end

      ctx = %{run_id: run_id, emit: emit_fn}

      case mod.run(args, ctx) do
        {:ok, result} ->
          %{
            "content" => [
              %{"type" => "text", "text" => Jason.encode!(Map.put(result, :status, "ok"))}
            ]
          }

        {:error, err} ->
          {:error, %{
            code: Map.get(err, :code, 1000),
            message: Map.get(err, :message, "Flow error"),
            data: Map.get(err, :data, err)
          }}
      end
    else
      _ -> {:error, %{code: -32602, message: "Unknown tool #{inspect(full)}"}}
    end
  end

  defp resources_list do
    # Stub. Replace with your real persistence query.
    %{
      "resources" => [
        %{
          "uri" => "hermetica://runs/demo",
          "name" => "Recent run (demo)",
          "mimeType" => "application/json"
        }
      ]
    }
  end

  defp resources_read(%{"uri" => "hermetica://runs/demo"}) do
    body = %{"run_id" => "demo", "status" => "ok", "summary" => %{"ok" => 3, "failed" => 0}}
    %{"contents" => [%{"type" => "text", "mimeType" => "application/json", "text" => Jason.encode!(body)}]}
  end
  defp resources_read(_), do: {:error, %{code: -32602, message: "Unknown resource"}}

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
        %{"role" => "user", "content" => %{"type" => "text", "text" =>
          "Please analyze Hermetica run #{id}, identify failing steps, and propose a minimal repro."
        }}
      ]
    }
  end

  defp prompts_get(_), do: {:error, %{code: -32602, message: "Unknown prompt/args"}}
end
