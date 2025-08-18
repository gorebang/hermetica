# lib/hermetica/mcp/util.ex
defmodule Hermetica.MCP.Util do
  @moduledoc false

  def wrap_jsonrpc(id, {:error, err}) do
    %{"jsonrpc" => "2.0", "id" => id, "error" => err}
  end

  def wrap_jsonrpc(id, result) do
    %{"jsonrpc" => "2.0", "id" => id, "result" => result}
  end
end
