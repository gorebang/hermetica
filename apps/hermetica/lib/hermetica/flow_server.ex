defmodule Hermetica.FlowServer do
  use GenServer
  require Logger
  import Bitwise

  @registry Hermetica.Registry

  # --- Public API ---

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

  @doc """
  Rerun a previous execution using its `run_id`.

  Pass the *flow module* (e.g. `Hermetica.Flows.Hello`).
  Returns:
    * `{:ok, ctx}` on success
    * `{:error, reason}` on failure
    * `{:error, :not_found}` if the run_id doesn't exist
  """
  def rerun(flow_module, run_id, timeout \\ 5_000) do
    case Store.Repo.get(Store.Run, run_id) do
      %Store.Run{event: event} -> trigger_sync(flow_module, event, timeout)
      nil -> {:error, :not_found}
    end
  end

  # Ensure each flow gets a unique child id (works in tests & prod)
  @doc false
  def child_spec(flow_module) do
    %{
      id: {:flow_server, flow_module},
      start: {__MODULE__, :start_link, [flow_module]},
      type: :worker,
      restart: :permanent,
      shutdown: 5_000
    }
  end


  # --- GenServer callbacks ---

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
    Logger.info("flow #{name} triggered with #{inspect(event)}")

    # 1) persist run (masking the stored event)
    masked_event = Hermetica.Mask.maybe(event)

    {:ok, run} =
      Store.Repo.insert(
        Store.Run.changeset(%Store.Run{}, %{
          flow: name,
          status: :running,
          event: masked_event
        })
      )

    # correlate logs with DB UUID
    Logger.metadata(run_id: run.id)

    ctx0 = %{run_id: run.id, event: event, out: %{}}

    result =
      Enum.reduce_while(steps, {:ok, ctx0}, fn {step_name, step_def}, {:ok, ctx} ->
        {fun, opts} = step_fun_and_opts(step_def)

        # record step start
        _ =
          Store.Repo.insert(
            Store.StepRun.changeset(%Store.StepRun{}, %{
              run_id: ctx.run_id,
              step: to_string(step_name),
              status: :running,
              input: Hermetica.Mask.maybe(ctx)
            })
          )

        case Hermetica.StepRunner.run(fun, ctx, opts) do
          {:ok, out} ->
            _ =
              Store.Repo.insert(
                Store.StepRun.changeset(%Store.StepRun{}, %{
                  run_id: ctx.run_id,
                  step: to_string(step_name),
                  status: :succeeded,
                  output: Hermetica.Mask.maybe(out)
                })
              )

            {:cont, {:ok, put_in(ctx.out[step_name], out)}}

          {:error, err} ->
            _ =
              Store.Repo.insert(
                Store.StepRun.changeset(%Store.StepRun{}, %{
                  run_id: ctx.run_id,
                  step: to_string(step_name),
                  status: :failed,
                  error: %{"error" => inspect(err)}
                })
              )

            case Keyword.get(opts, :on_error, :halt) do
              :continue ->
                {:cont, {:ok, ctx}}

              {:compensate, comp_fun} when is_function(comp_fun, 1) ->
                case comp_fun.(ctx) do
                  {:ok, comp_out} ->
                    _ =
                      Store.Repo.insert(
                        Store.StepRun.changeset(%Store.StepRun{}, %{
                          run_id: ctx.run_id,
                          step: to_string(step_name),
                          status: :succeeded,
                          output: Hermetica.Mask.maybe(comp_out)
                        })
                      )

                    {:cont, {:ok, put_in(ctx.out[step_name], comp_out)}}

                  _ ->
                    {:cont, {:ok, ctx}}
                end

              _ ->
                {:halt, {:error, err}}
            end
        end
      end)

    # 3) finalize run row
    case result do
      {:ok, ctx} ->
        _ =
          Store.Repo.update(
            Store.Run.changeset(run, %{
              status: :succeeded,
              out: Hermetica.Mask.maybe(ctx.out)
            })
          )

      {:error, _err} ->
        _ = Store.Repo.update(Store.Run.changeset(run, %{status: :failed}))
    end

    Logger.info("run finished: #{inspect(result)}")
    result
  end

  defp step_fun_and_opts({:fun, fun}) when is_function(fun, 1), do: {fun, []}
  defp step_fun_and_opts({:fun, fun, opts}) when is_function(fun, 1) and is_list(opts),
    do: {fun, opts}

  # (Optional) UUID v4 generator (currently unused)
  # Keep if you plan to generate public tokens distinct from DB ids.
  defp uuid4 do
    <<a::32, b::16, c::16, d::16, e::48>> = :crypto.strong_rand_bytes(16)
    c = (c &&& 0x0FFF) ||| 0x4000
    d = (d &&& 0x3FFF) ||| 0x8000

    :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b", [a, b, c, d, e])
    |> IO.iodata_to_binary()
  end
end
