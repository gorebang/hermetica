defmodule Hermetica.RerunTest do
  use ExUnit.Case, async: false

  import Ecto.Query, only: [from: 2]
  alias Ecto.Adapters.SQL.Sandbox
  alias Store.{Repo, Run}
  alias Hermetica.FlowServer
  alias Hermetica.TestFlows.OK

  setup do
    :ok = Sandbox.checkout(Repo)
    Sandbox.mode(Repo, {:shared, self()})

    unless Process.whereis(Hermetica.Registry) do
      start_supervised!({Registry, keys: :unique, name: Hermetica.Registry})
    end

    start_supervised!({FlowServer, OK})
    :ok
  end

  test "reruns a stored run by id" do
    assert {:ok, _ctx1} = FlowServer.trigger_sync(OK, %{who: "earth"})

    %Run{id: run_id, event: event1} =
      Repo.one!(
        from(r in Run,
          where: r.flow == "ok",
          order_by: [desc: r.inserted_at],
          limit: 1
        )
      )

    assert {:ok, ctx2} = FlowServer.rerun(OK, run_id)
    assert ctx2.event == event1
    assert Map.has_key?(ctx2.out, :compose)
  end

  test "rerun returns :not_found for unknown id" do
    assert {:error, :not_found} = FlowServer.rerun(OK, Ecto.UUID.generate())
  end
end
