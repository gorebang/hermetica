# lib/hermetica/flows/example.ex
defmodule Hermetica.Flows.Example do
  @behaviour Hermetica.Flow

  @impl true
  def name, do: "example"

  @impl true
  def description, do: "A demo flow that echoes input and simulates work."

  @impl true
  def schema do
    %{
      "type" => "object",
      "required" => ["message"],
      "properties" => %{
        "message" => %{"type" => "string", "description" => "Text to echo"},
        "steps"   => %{"type" => "integer", "default" => 3, "minimum" => 1, "maximum" => 10},
        "dry_run" => %{"type" => "boolean", "default" => false}
      }
    }
  end

  @impl true
  def run(args, ctx) do
    steps = Map.get(args, "steps", 3)
    for i <- 1..steps do
      Process.sleep(150)
      ctx.emit.({:stage, "work", %{step: i, total: steps}})
    end

    {:ok,
     %{
       ok: true,
       echoed: args["message"],
       steps: steps,
       dry_run: Map.get(args, "dry_run", false),
       run_id: ctx.run_id
     }}
  end
end
