defmodule Hermetica.StepRunnerTest do
  use ExUnit.Case, async: true

  alias Hermetica.StepRunner

  test "retries with exponential backoff until success" do
    # Fail twice, then succeed
    {:ok, agent} =
      Agent.start_link(fn -> 0 end)

    fun = fn _ctx ->
      n = Agent.get_and_update(agent, &{&1, &1 + 1})
      case n do
        0 -> {:error, :boom}
        1 -> {:error, :boom}
        _ -> {:ok, %{ok: true}}
      end
    end

    {micros, result} = :timer.tc(fn ->
      StepRunner.run(fun, %{}, retries: 2, timeout: 1_000)
    end)

    # Expect at least 200ms + 400ms ~= 600ms of waiting (exponential 200, 400)
    # Allow some slack; we assert >= 550ms and < 3s
    assert micros >= 550_000
    assert micros < 3_000_000
    assert {:ok, %{ok: true}} = result
  end

  test "returns {:error, reason} after exhausting retries" do
    fun = fn _ -> {:error, :nope} end
    {micros, result} = :timer.tc(fn ->
      StepRunner.run(fun, %{}, retries: 2, timeout: 200)
    end)

    # Two waits: ~200ms + ~400ms -> ~600ms minimum
    assert micros >= 550_000
    assert {:error, :nope} = result
  end

  test "times out and retries accordingly" do
    # Each run sleeps longer than timeout so it triggers :timeout
    fun = fn _ ->
      Process.sleep(400)
      {:ok, :too_slow}
    end

    {micros, result} =
      :timer.tc(fn ->
        StepRunner.run(fun, %{}, timeout: 100, retries: 1)
      end)

    # Expect at least one timeout + one backoff (200ms) ~= 300ms+
    assert micros >= 250_000
    # After retry, it still times out → {:error, :timeout}
    assert {:error, :timeout} = result
  end
end
