# lib/hermetica/flow.ex
defmodule Hermetica.Flow do
  @moduledoc """
  Behaviour any Hermetica flow implements so MCP can introspect & run it.
  """

  @callback name() :: String.t()
  @callback description() :: String.t()
  @callback schema() :: map()
  @callback run(args :: map(), ctx :: map()) :: {:ok, map()} | {:error, map()}

  # Optional: emit progress events. Your flows can call ctx.emit/1.
end
