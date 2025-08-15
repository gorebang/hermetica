defmodule Hermetica.Flows.Hello do
  import Hermetica.DSL

  defflow "hello" do
    step :compose, fn _ctx ->
      {:ok, %{text: "Hello from Hermetica"}}
    end

    # Now with retries + timeout
    step :sometimes_flaky, [retries: 2, timeout: 1_000], fn _ctx ->
      if :rand.uniform() < 0.6, do: {:error, :flaky}, else: {:ok, %{ok: true}}
    end

    # or with compensation:
    step :fallback_to_cache, [on_error: {:compensate, &__MODULE__.load_cache/1}], fn _ctx ->
      {:error, :upstream_down}
    end

def load_cache(_ctx), do: {:ok, %{from: :cache}}


    step :print, fn %{out: %{compose: %{text: t}}} ->
      IO.puts(t)
      {:ok, %{ok: true}}
    end
  end
end
