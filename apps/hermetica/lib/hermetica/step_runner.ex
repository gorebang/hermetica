defmodule Hermetica.StepRunner do
  @moduledoc """
  Runs a single step function with timeout + retries.
  Retries use exponential backoff: min(2000ms, 200ms * 2^attempts_used).
  """

  require Logger
  @default_timeout 5_000

  @spec run((map -> {:ok, any} | {:error, any}), map, keyword) ::
          {:ok, any} | {:error, any}
  def run(fun, ctx, opts \\ []) when is_function(fun, 1) and is_map(ctx) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    retries = Keyword.get(opts, :retries, 0)
    do_run(fun, ctx, timeout, retries, 0)
  end

  defp do_run(fun, ctx, timeout, retries_left, attempts_used) do
    task = Task.async(fn -> fun.(ctx) end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, _} = ok} ->
        ok

      {:ok, {:error, err}} ->
        retry_or_fail({:error, err}, fun, ctx, timeout, retries_left, attempts_used)

      nil ->
        retry_or_fail({:error, :timeout}, fun, ctx, timeout, retries_left, attempts_used)
    end
  end

  defp retry_or_fail(reason, _fun, _ctx, _timeout, 0, _attempts_used), do: reason

  defp retry_or_fail(reason, fun, ctx, timeout, retries_left, attempts_used) do
    sleep = min(2000, trunc(:math.pow(2, attempts_used) * 200))
    Logger.warning("retrying step (#{retries_left} left) in #{sleep}ms due to #{inspect(reason)}")
    Process.sleep(sleep)
    do_run(fun, ctx, timeout, retries_left - 1, attempts_used + 1)
  end
end
