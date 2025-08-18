# lib/hermetica/mcp/transport.ex
defmodule Hermetica.MCP.Transport do
  @moduledoc false
  # JSON-RPC over stdio with Content-Length framing (LSP-style).
  # - start_link/1 boots a loop that reads framed requests from STDIN
  # - write_message/1 frames + writes any map as JSON
  # - send_partial/3 streams "tools/partial" either to STDOUT (:stdio) or test mailbox ({:test, pid})

  alias Hermetica.MCP.Router

  # --- Public API -------------------------------------------------------------

  @doc """
  Starts the blocking stdio loop in a Task.
  Put this in your Application children as:
      {Task, fn -> Hermetica.MCP.Transport.start_link(nil) end}
  """
  def start_link(_opts \\ nil) do
    Task.start_link(fn -> loop() end)
  end

  @doc """
  Send a tools/partial notification.

  In prod: pass `:stdio` as `io` to stream framed JSON to STDOUT.
  In tests: pass `{:test, pid}` and the partial will be delivered to the test process mailbox:
      {:tools_partial, %{id: <rpc id>, payload: <map>}}
  """
  def send_partial({:test, pid}, id, payload) when is_pid(pid) do
    send(pid, {:tools_partial, %{id: id, payload: payload}})
    :ok
  end

  def send_partial(:stdio, id, payload) do
    msg = %{
      "jsonrpc" => "2.0",
      "method"  => "tools/partial",
      "params"  => Map.merge(%{"id" => id}, payload)
    }

    write_message(msg)
  end

  @doc """
  Frames and writes a JSON-RPC message to STDOUT.
  """
  def write_message(map) when is_map(map) do
    bin = Jason.encode!(map)
    header = "Content-Length: #{byte_size(bin)}\r\n\r\n"
    IO.binwrite(:stdio, header)
    IO.binwrite(:stdio, bin)
    :ok
  end

  # --- Loop ------------------------------------------------------------------

  @doc false
  def loop do
    case read_message() do
      :eof ->
        :ok

      {:error, reason} ->
        IO.warn("Transport: failed to read message (#{inspect(reason)}); continuing")
        loop()

      {:ok, req} ->
        # Always route via Router; it returns a full JSON-RPC envelope.
        # The router will call `send_partial/3` for streaming.
        resp =
          try do
            Router.handle(req, :stdio)
          rescue
            e ->
              id = Map.get(req, "id")
              %{
                "jsonrpc" => "2.0",
                "id" => id,
                "error" => %{
                  "code" => -32603,
                  "message" => Exception.message(e)
                }
              }
          end

        write_message(resp)
        loop()
    end
  end

  # --- Reading ---------------------------------------------------------------

  @doc false
  def read_message do
    with {:ok, len} <- read_content_length(),
         {:ok, body} <- read_exact(len),
         {:ok, map}  <- decode_json(body) do
      {:ok, map}
    else
      :eof -> :eof
      {:eof, _} -> :eof
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_content_length do
    read_headers(%{})
  end

  defp read_headers(acc) do
    case IO.binread(:stdio, :line) do
      :eof ->
        :eof

      data when is_binary(data) ->
        line = String.trim_trailing(data, "\r\n")

        if line == "" do
          case Map.fetch(acc, "content-length") do
            {:ok, v} ->
              case Integer.parse(v) do
                {len, _} when len >= 0 -> {:ok, len}
                _ -> {:error, :bad_content_length}
              end

            :error ->
              {:error, :missing_content_length}
          end
        else
          {k, v} = parse_header(line)
          read_headers(Map.put(acc, String.downcase(k), String.trim(v)))
        end
    end
  end

  defp parse_header(line) do
    case String.split(line, ":", parts: 2) do
      [k, v] -> {String.trim(k), v}
      _ -> {line, ""}
    end
  end

  defp read_exact(len) when is_integer(len) and len >= 0 do
    case IO.binread(:stdio, len) do
      :eof -> {:eof, :short_read}
      bin when is_binary(bin) and byte_size(bin) == len -> {:ok, bin}
      other -> {:error, {:short_read, other}}
    end
  end

  defp decode_json(bin) do
    case Jason.decode(bin) do
      {:ok, map} when is_map(map) -> {:ok, map}
      {:ok, _} -> {:error, :not_a_map}
      {:error, err} -> {:error, err}
    end
  end
end
