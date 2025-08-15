defmodule Hermetica.FlowServer do
  use GenServer
  require Logger

  @registry Hermetica.Registry

  ## ————— Public API —————

  # Start a server for a given flow module (e.g., Hermetica.Flows.Hello)
  def start_link(flow_module) when is_atom(flow_module) do
    name = {:via, Registry, {@registry, flow_module}}
    GenServer.start_link(__MODULE__, flow_module, name: name)
  end

  # Trigger a run with an event/payload map
  def trigger(flow_module, event \\ %{}) when is_atom(flow_module) and is_map(event) do
    GenServer.cast({:via, Registry, {@registry, flow_module}}, {:trigger, event})
  end

  ## ————— GenServer callbacks —————

  @impl true
  def init(flow_module) do
    flow = flow_module.__flow__()
    {:ok, %{flow_module: flow_module, flow: flow}}
  end

  @impl true
  def handle_cast({:trigger, event}, %{flow: %{name: name, steps: steps}} = state) do
    Logger.info("flow #{name} triggered with #{inspect(event)}")

  result =
    Enum.reduce_while(steps, {:ok, %{event: event, out: %{}}}, fn {step_name, step_def}, {:ok, ctx} ->
      {fun, opts} = step_fun_and_opts(step_def)

      case Hermetica.StepRunner.run(fun, ctx, opts) do
        {:ok, out} ->
          {:cont, {:ok, %{ctx | out: Map.put(ctx.out, step_name, out)}}}

        {:error, err} ->
          Logger.error("step #{step_name} failed: #{inspect(err)}")
          {:halt, {:error, err}}
      end
    end)


    Logger.info("run finished: #{inspect(result)}")
    {:noreply, state}
  end

  ## ————— Internals —————

  # DSL step tuples we expect:
  #   {:fun, fun} OR {:fun, fun, opts}
  defp step_fun_and_opts({:fun, fun}) when is_function(fun, 1), do: {fun, []}
  defp step_fun_and_opts({:fun, fun, opts}) when is_function(fun, 1) and is_list(opts), do: {fun, opts}

  # Minimal runner; adds try/catch to avoid crashing the GenServer
  defp run_step(fun, ctx, _opts) do
    try do
      fun.(ctx)
    rescue
      e -> {:error, e}
    catch
      kind, val -> {:error, {kind, val}}
    end
  end
end
