defmodule Hermetica.TestFlows.OK do
  def __flow__ do
    %{
      name: "ok",
      steps: [
        {:compose, {:fun, &__MODULE__.compose/1}},
        {:sometimes_flaky, {:fun, &__MODULE__.sometimes_flaky/1, [retries: 2, timeout: 200]}},
        {:print, {:fun, &__MODULE__.print/1}}
      ]
    }
  end

  # Deterministic flaky: fail once per run then succeed
  def compose(_ctx) do
    Process.put(:ok_flaky_attempt, 0)
    {:ok, %{text: "hi"}}
  end

  def sometimes_flaky(_ctx) do
    case Process.get(:ok_flaky_attempt) do
      0 -> Process.put(:ok_flaky_attempt, 1); {:error, :flaky}
      _ -> {:ok, %{ok: true}}
    end
  end

  def print(%{out: %{compose: %{text: t}}}) do
    IO.puts(t)
    {:ok, %{printed: true}}
  end
end

defmodule Hermetica.TestFlows.Comp do
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

defmodule Hermetica.TestFlows.Halt do
  def __flow__ do
    %{
      name: "halt_demo",
      steps: [
        {:ok1, {:fun, &__MODULE__.ok1/1}},
        {:boom, {:fun, &__MODULE__.boom/1}},   # default :halt
        {:never, {:fun, &__MODULE__.never/1}}  # should not run
      ]
    }
  end

  def ok1(_ctx), do: {:ok, %{one: 1}}
  def boom(_ctx), do: {:error, :kaput}
  def never(_ctx), do: {:ok, %{should_not: :run}}
end
