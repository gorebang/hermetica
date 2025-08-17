defmodule Hermetica.TestFlows do
  import Hermetica.DSL

  # Succeeds, but has a flaky step with retries
  defmodule OK do
    defflow "ok" do
      step :compose, fn _ctx -> {:ok, %{text: "hi"}} end

      step :sometimes_flaky, [retries: 2, timeout: 200], fn _ctx ->
        if :rand.uniform() < 0.5, do: {:error, :flaky}, else: {:ok, %{ok: true}}
      end

      step :print, fn %{out: %{compose: %{text: t}}} ->
        IO.puts(t)
        {:ok, %{printed: true}}
      end
    end
  end

  # Fails a step but compensates
  defmodule Comp do
    defflow "comp" do
      step :compose, fn _ -> {:ok, %{text: "hello"}} end

      step :write_cache, [on_error: {:compensate, &__MODULE__.fallback/1}], fn _ ->
        {:error, :upstream_down}
      end

      step :done, fn _ -> {:ok, %{ok: true}} end
    end

    def fallback(_ctx), do: {:ok, %{cached: false}}
  end

  # Fails hard (default :halt)
  defmodule Halt do
    defflow "halt" do
      step :boom, fn _ -> {:error, :kaput} end
      step :never, fn _ -> {:ok, :nope} end
    end
  end
end
