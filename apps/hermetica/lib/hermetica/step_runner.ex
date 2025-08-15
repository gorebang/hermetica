defmodule Hermetica.StepRunner do
  require Logger

  @default_timeout 5_000

  def run(fun, ctx, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    retries = Keyword.get(opts, :retries, 0)
    do_run(fun, ctx, timeout, retries)
  end

  defp do_run(fun, ctx, timeout, retries_left) do
    task = Task.async(fn -> fun.(ctx) end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, _} = ok} ->
        ok

      {:ok, {:error, err}} ->
        retry_or_fail({:error, err}, fun, ctx, timeout, retries_left)

      nil ->
        retry_or_fail({:error, :timeout}, fun, ctx, timeout, retries_left)
    end
  end

  defp retry_or_fail(reason, fun, ctx, timeout, 0), do: reason
  defp retry_or_fail(reason, fun, ctx, timeout, n) do
    Logger.warning("retrying step (#{n} left) due to #{inspect(reason)}")
    Process.sleep(jitter(200, 800))
    do_run(fun, ctx, timeout, n - 1)
  end

  defp jitter(min, max), do: :rand.uniform(max - min + 1) + min - 1
end
