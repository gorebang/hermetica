# lib/hermetica/mcp/transport.ex
defmodule Hermetica.MCP.Transport do
  @moduledoc """
  JSON-RPC over stdio with Content-Length framing (LSP-style).
  Also provides tools/partial streaming helpers.
  """

  alias Hermetica.MCP.Router

  @header_sep "\r\n\r\n"

  def start_link(_arg \\ nil) do
    Task.start_link(fn -> loop() end)
  end

  defp loop do
    case read_message() do
      :eof -> :ok
      {:error, _} -> :ok
      {:ok, req} ->
        # Pass the current IO device as 'io' so Router can stream partials
        resp = Router.handle(req, :stdio)
        write_message(resp)
        loop()
    end
  end

  # ---- Framing ----

  defp read_message do
    with {:ok, headers} <- read_headers(""),
         {"content-length", len} <- parse_content_length(headers),
         {:ok, body} <- read_exact(len),
         {:ok, req} <- Jason.decode(body)
    do
      {:ok, req}
    else
      :eof -> :eof
      {:error, _}=e -> e
      _ -> {:error, :bad_frame}
    end
  end

  defp read_headers(acc) do
    case IO.binread(:stdio, 1) do
      :eof -> :eof
      {:error, _}=e -> e
      data ->
        acc = acc <> data
        if String.ends_with?(acc, @header_sep) do
          {:ok, acc}
        else
          read_headers(acc)
        end
    end
  end

  defp parse_content_length(headers) do
    case Regex.run(~r/Content-Length:\s*(\d+)/i, headers) do
      [_, len] -> {"content-length", String.to_integer(len)}
      _ -> {:error, :no_content_length}
    end
  end

  defp read_exact(len), do: read_exact(len, <<>>)
  defp read_exact(0, acc), do: {:ok, acc}
  defp read_exact(n, acc) do
    case IO.binread(:stdio, n) do
      :eof -> :eof
      {:error, _}=e -> e
      data ->
        remaining = n - byte_size(data)
        read_exact(remaining, acc <> data)
    end
  end

  defp write_message(map) when is_map(map) do
    bin = Jason.encode!(map)
    header = "Content-Length: " <> Integer.to_string(byte_size(bin)) <> "\r\n\r\n"
    IO.binwrite(:stdio, header <> bin)
  end

  # ---- Streaming Partials ----
  # Send a tools/partial notification bound to a call id.
  def send_partial(:stdio, id, payload) do
    msg = %{
      "jsonrpc" => "2.0",
      "method"  => "tools/partial",
      "params"  => Map.merge(%{"id" => id}, payload)
    }

    write_message(msg)
  end
end
