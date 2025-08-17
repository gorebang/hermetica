defmodule Hermetica.PersistenceTest do
  use ExUnit.Case, async: false

  import Ecto.Query, only: [from: 2]
  alias Ecto.Adapters.SQL.Sandbox
  alias Store.{Repo, Run, StepRun}
  alias Hermetica.FlowServer
  alias Hermetica.TestFlows.{OK, Comp, Halt}

  setup do
    :ok = Sandbox.checkout(Store.Repo)
    Sandbox.mode(Store.Repo, {:shared, self()})

    unless Process.whereis(Hermetica.Registry) do
      start_supervised!({Registry, keys: :unique, name: Hermetica.Registry})
    end

    start_supervised!({Hermetica.FlowServer, Hermetica.TestFlows.OK})
    start_supervised!({Hermetica.FlowServer, Hermetica.TestFlows.Comp})
    start_supervised!({Hermetica.FlowServer, Hermetica.TestFlows.Halt})
    :ok
  end

  test "persists successful run with step outputs" do
    assert {:ok, ctx} = FlowServer.trigger_sync(OK, %{who: "world"})
    run_id = ctx.run_id

    # run row (scoped by id)
    run = Repo.get!(Run, run_id)
    assert run.flow == "ok"
    assert run.status == :succeeded
    assert is_map(run.event)
    assert is_map(run.out)
    assert ctx.event == %{who: "world"}

    # only final/succeeded step rows, in execution order
    succeeded_steps =
      Repo.all(
        from s in StepRun,
          where: s.run_id == ^run_id and s.status == :succeeded,
          order_by: [asc: s.inserted_at],
          select: s.step
      )

    assert succeeded_steps == ["compose", "sometimes_flaky", "print"]

    # ctx.out has compose + print keys at least
    assert %{
             compose: %{text: _},
             print: %{printed: true}
           } = Map.take(ctx.out, [:compose, :print])
  end

  test "persists compensations and marks run succeeded" do
    assert {:ok, ctx} = FlowServer.trigger_sync(Comp, %{})
    run_id = ctx.run_id

    run = Repo.get!(Run, run_id)
    assert run.flow == "compensate_demo"
    assert run.status == :succeeded

    steps =
      Repo.all(
        from s in StepRun,
          where: s.run_id == ^run_id,
          order_by: [asc: s.inserted_at]
      )

    # There should be at least one failed attempt for "fallback" and a succeeded compensation
    assert Enum.any?(steps, &(&1.step == "fallback" and &1.status == :failed))
    assert Enum.any?(steps, &(&1.step == "fallback" and &1.status == :succeeded))

    # ctx.out should reflect compensated output
    assert %{fallback: %{default: true}} = ctx.out
  end

  test "halts on error and marks run failed" do
    assert {:error, :kaput} = FlowServer.trigger_sync(Halt, %{})

    # Grab the most recent halt_demo run
    run =
      Repo.one!(
        from r in Run,
          where: r.flow == "halt_demo",
          order_by: [desc: r.inserted_at],
          limit: 1
      )

    assert run.status == :failed

    steps =
      Repo.all(
        from s in StepRun,
          where: s.run_id == ^run.id
      )

    # The failing step recorded as failed, and the next step never ran
    assert Enum.any?(steps, &(&1.step == "boom" and &1.status == :failed))
    refute Enum.any?(steps, &(&1.step == "never"))
  end
end
