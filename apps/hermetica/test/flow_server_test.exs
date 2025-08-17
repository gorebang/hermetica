defmodule Hermetica.FlowServerTest do
  use ExUnit.Case, async: false

  alias Hermetica.FlowServer
  alias Ecto.Adapters.SQL.Sandbox
  alias Store.Repo

  #
  # Test-only flow modules that implement __flow__/0
  #
  defmodule FlowHalt do
    def __flow__ do
      %{
        name: "halt_demo",
        steps: [
          {:ok1, {:fun, &__MODULE__.ok1/1}},
          {:halt_step, {:fun, &__MODULE__.halt_step/1}}, # default on_error = :halt
          {:ok2, {:fun, &__MODULE__.ok2/1}}
        ]
      }
    end

    def ok1(_ctx), do: {:ok, %{one: 1}}
    def halt_step(_ctx), do: {:error, :boom}
    def ok2(_ctx), do: {:ok, %{two: 2}}
  end

  defmodule FlowContinue do
    def __flow__ do
      %{
        name: "continue_demo",
        steps: [
          {:ok1, {:fun, &__MODULE__.ok1/1}},
          {:skip_me, {:fun, &__MODULE__.fail/1, [on_error: :continue]}},
          {:ok2, {:fun, &__MODULE__.ok2/1}}
        ]
      }
    end

    def ok1(_ctx), do: {:ok, %{one: 1}}
    def fail(_ctx), do: {:error, :oops}
    def ok2(_ctx), do: {:ok, %{two: 2}}
  end

  defmodule FlowCompensate do
    def __flow__ do
      %{
        name: "compensate_demo",
        steps: [
          {:ok1, {:fun, &__MODULE__.ok1/1}},
          {:fallback, {:fun, &__MODULE__.fail/1, [on_error: {:compensate, &__MODULE__.comp/1}]}},
          {:ok2, {:fun, &__MODULE__.ok2/1}}
        ]
      }
    end

    def ok1(_ctx), do: {:ok, %{one: 1}}
    def fail(_ctx), do: {:error, :flaky}
    def comp(_ctx), do: {:ok, %{default: true}}
    def ok2(_ctx), do: {:ok, %{two: 2}}
  end

  defmodule FlowRunID do
    def __flow__ do
      %{name: "run_id_demo", steps: [ok: {:fun, &__MODULE__.ok/1}]}
    end

    def ok(%{run_id: run_id}) when is_binary(run_id), do: {:ok, %{seen: run_id}}
  end

  #
  # SQL Sandbox: checkout and switch to shared mode so spawned processes
  # (Registry, FlowServers) can use the same DB connection.
  #
  setup do
    :ok = Sandbox.checkout(Repo)
    Sandbox.mode(Repo, {:shared, self()})

    # Ensure the Registry exists AFTER sandbox is shared
    unless Process.whereis(Hermetica.Registry) do
      start_supervised!({Registry, keys: :unique, name: Hermetica.Registry})
    end

    :ok
  end

  test "trigger_sync halts on default :halt policy" do
    {:ok, _pid} = start_supervised({FlowServer, FlowHalt})
    assert {:error, :boom} = FlowServer.trigger_sync(FlowHalt, %{x: 1})
  end

  test "on_error: :continue skips failed step and keeps running" do
    {:ok, _pid} = start_supervised({FlowServer, FlowContinue})
    assert {:ok, ctx} = FlowServer.trigger_sync(FlowContinue, %{x: 1})

    assert is_binary(ctx.run_id)
    assert ctx.event == %{x: 1}

    # ok1 and ok2 outputs recorded, skip_me not present
    assert %{ok1: %{one: 1}, ok2: %{two: 2}} = ctx.out
    refute Map.has_key?(ctx.out, :skip_me)
  end

  test "on_error: {:compensate, fun} records fallback output and continues" do
    {:ok, _pid} = start_supervised({FlowServer, FlowCompensate})
    assert {:ok, ctx} = FlowServer.trigger_sync(FlowCompensate, %{})

    assert is_binary(ctx.run_id)
    assert %{ok1: %{one: 1}, fallback: %{default: true}, ok2: %{two: 2}} = ctx.out
  end

  test "run_id is set and included in ctx" do
    {:ok, _pid} = start_supervised({FlowServer, FlowRunID})
    assert {:ok, ctx} = FlowServer.trigger_sync(FlowRunID, %{})
    assert is_binary(ctx.run_id)
    assert String.length(ctx.run_id) >= 36
    assert %{ok: %{seen: seen}} = ctx.out
    assert seen == ctx.run_id
  end
end
