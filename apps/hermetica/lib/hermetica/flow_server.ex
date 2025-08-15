defmodule Hermetica.FlowServer do
  use GenServer
  require Logger

  @registry Hermetica.Registry

  ## ── Public API ──────────────────────────────────────────────────────────────

  # Start a server bound to a specific flow module (e.g., Hermetica.Flows.Hello)
  def start_link(flow_module) when is_atom(flow_module) do
    name = {:via, Registry, {@registry, flow_module}}
    GenServer.start_link(__MODULE__, flow_module, name: name)
  end

  # Fire-and-forget trigger
  def trigger(flow_module, event \\ %{}) when is_atom(flow_module) and is_map(event) do
    GenServer.cast({:via, Registry, {@registry, flow_module}}, {:trigger, event})
  end

  # Synchronous trigger that returns {:ok, ctx} | {:error, reason}
  def trigger_sync(flow_module, event \\ %{}, timeout \\ 5_000)
      when is_atom(flow_module) and is_map(event) do
    GenServer.call({:via, Registry, {@registry, flow_module}}, {:trigger_sync, event}, timeout)
  end

  ## ── GenServer callbacks ────────────────────────────────────────────────────

  @impl true
  def init(flow_module) do
    {:ok, %{flow_module: flow_module, flow: flow_module.__flow__()}}
  end

  @impl true
  def handle_cast({:trigger, event}, state) do
    _ = do_run(state.flow, event) # fire-and-forget
    {:noreply, state}
  end

  @impl true
  def handle_call({:trigger_sync, event}, _from, state) do
    result = do_run(state.flow, event)
    {:reply, result, state}
  end

  ## ── Internals ──────────────────────────────────────────────────────────────

  defp do_run(%{name: name, steps: steps}, event) do
    Logger.info("flow #{name} triggered with #{inspect(event)}")
    ctx0 = %{event: event, out: %{}}

    result =
      Enum.reduce_while(steps, {:ok, ctx0}, fn {step_name, step_def}, {:ok, ctx} ->
        {fun, opts} = step_fun_and_opts(step_def)

        case Hermetica.StepRunner.run(fun, ctx, opts) do
          {:ok, out} ->
            {:cont, {:ok, put_in(ctx.out[step_name], out)}}

          {:error, err} ->
            Logger.error("step #{step_name} failed: #{inspect(err)}")

            case Keyword.get(opts, :on_error, :halt) do
              :continue ->
                # skip this step's output, keep going
                {:cont, {:ok, ctx}}

              {:compensate, comp_fun} when is_function(comp_fun, 1) ->
                case comp_fun.(ctx) do
                  {:ok, comp_out} -> {:cont, {:ok, put_in(ctx.out[step_name], comp_out)}}
                  _ -> {:cont, {:ok, ctx}}
                end

              _ ->
                # default policy: halt the run
                {:halt, {:error, err}}
            end
        end
      end)

    Logger.info("run finished: #{inspect(result)}")
    result
  end

  # DSL step tuples we expect:
  #   {:fun, fun} OR {:fun, fun, opts}
  defp step_fun_and_opts({:fun, fun}) when is_function(fun, 1), do: {fun, []}
  defp step_fun_and_opts({:fun, fun, opts}) when is_function(fun, 1) and is_list(opts), do: {fun, opts}
end
