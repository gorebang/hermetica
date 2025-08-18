defmodule Hermetica.MCP.Util do
  @moduledoc false

  def wrap_jsonrpc(id, {:error, err}) do
    %{"jsonrpc" => "2.0", "id" => id, "error" => stringify_keys(err)}
  end

  def wrap_jsonrpc(id, result) do
    %{"jsonrpc" => "2.0", "id" => id, "result" => result}
  end

  defp stringify_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} ->
      key =
        case k do
          k when is_atom(k) -> Atom.to_string(k)
          k -> k
        end

      val = if is_map(v), do: stringify_keys(v), else: v
      {key, val}
    end)
    |> Map.new()
  end
end
