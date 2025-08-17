defmodule Hermetica.Replay do
  @moduledoc "Helpers to rerun past executions."
  def rerun(flow_module, run_id),
    do: Hermetica.FlowServer.rerun(flow_module, run_id)
end
