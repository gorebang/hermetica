# lib/hermetica/mcp/validate.ex
defmodule Hermetica.MCP.Validate do
  @moduledoc false
  def ensure_required!(%{"required" => reqs}, args) do
    missing = for k <- reqs, not Map.has_key?(args, k), do: k
    if missing != [], do: raise ArgumentError, "Missing required: #{Enum.join(missing, ", ")}"
    :ok
  end
  def ensure_required!(_, _), do: :ok
end
