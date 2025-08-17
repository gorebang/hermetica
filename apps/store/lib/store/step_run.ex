# apps/store/lib/store/step_run.ex
defmodule Store.StepRun do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :run_id, :step, :status, :input, :output, :error, :inserted_at, :updated_at]}
  schema "step_runs" do
    field :run_id, :binary_id
    field :step, :string
    field :status, Ecto.Enum, values: [:running, :succeeded, :failed]
    field :input, :map
    field :output, :map
    field :error, :map
    timestamps()
  end
  def changeset(sr, attrs), do: cast(sr, attrs, ~w(run_id step status input output error)a)
end
