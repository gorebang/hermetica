defmodule Mix.Tasks.Hermetica.Run do
  use Mix.Task
  @shortdoc "Run a Hermetica flow module"
  def run([mod | rest]) do
    Mix.Task.run("app.start")
    payload = case rest do
      [json] -> Jason.decode!(json)
      _ -> %{}
    end
    module = Module.concat([mod])
    Hermetica.FlowServer.trigger(module, payload)
    Process.sleep(300) # tiny wait for async cast
  end
end
