defmodule Store.Application do
  use Application
  def start(_t, _a), do: Supervisor.start_link([Store.Repo], strategy: :one_for_one, name: __MODULE__)
end
