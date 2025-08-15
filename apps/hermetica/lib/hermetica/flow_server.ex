defmodule Hermetica.FlowServer do
  use GenServer
  require Logger
  import Bitwise

  @registry Hermetica.Registry

  # --- API ---
  def start_link(flow_module) when is_atom(flow_module) do
    name = {:via, Registry, {@registry, flow_module}}
    GenServer.start_link(__MODULE__, flow_module, name: name)
  end

  def trigger(flow_module, event \\ %{}) when is_atom(flow_module) and is_map(event) do
    GenServer.cast({:via, Registry, {@registry, flow_module}}, {:trigger, event})
  end

  def trigger_sync(flow_module, event \\ %{}, timeout \\ 5_000)
      when is_atom(flow_module) and is_map(event) do
    GenServer.call({:via, Registry, {@registry, flow_module}}, {:trigger_sync, event}, timeout)
  end

  # --- Callbacks ---
  @impl true
  def init(flow_module) do
    {:ok, %{flow_module: flow_module, flow: flow_module.__flow__()}}
  end

  @impl true
  def handle_cast({:trigger, event}, state) do
    _ = do_run(state.flow, event)
    {:noreply, state}
  end

  @impl true
  def handle_call({:trigger_sync, event}, _from, state) do
    result = do_run(state.flow, event)
    {:reply, result, state}
  end

  # --- Internals ---
  defp do_run(%{name: name, steps: steps}, event) do
    run_id = uuid4()
    Logger.metadata(run_id: run_id)
    Logger.info("flow #{name} triggered with #{inspect(event)}")

    ctx0 = %{run_id: run_id, event: event, out: %{}}

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
                {:cont, {:ok, ctx}}

              {:compensate, comp_fun} when is_function(comp_fun, 1) ->
                case comp_fun.(ctx) do
                  {:ok, comp_out} -> {:cont, {:ok, put_in(ctx.out[step_name], comp_out)}}
                  _ -> {:cont, {:ok, ctx}}
                end

              _ ->
                {:halt, {:error, err}}
            end
        end
      end)

    Logger.info("run finished: #{inspect(result)}")
    result
  end

  defp step_fun_and_opts({:fun, fun}) when is_function(fun, 1), do: {fun, []}
  defp step_fun_and_opts({:fun, fun, opts}) when is_function(fun, 1) and is_list(opts), do: {fun, opts}

  # UUID v4 without deps
  defp uuid4 do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)
    c = (c &&& 0x0FFF) ||| 0x4000
    d = (d &&& 0x3FFF) ||| 0x8000
    :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b", [a, b, c, d, e])
    |> IO.iodata_to_binary()
  end
end
