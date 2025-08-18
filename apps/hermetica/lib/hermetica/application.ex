defmodule Hermetica.Application do
  use Application
  def start(_t, _a) do
    children = [
      {Registry, keys: :unique, name: Hermetica.Registry},
      {Hermetica.FlowServer, Hermetica.Flows.Hello},
      {Task, fn -> Hermetica.MCP.Transport.start_link(nil) end}
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end
end
