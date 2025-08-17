# apps/store/lib/store/run.ex
defmodule Store.Run do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :flow, :status, :event, :out, :inserted_at, :updated_at]}
  schema "runs" do
    field :flow, :string
    field :status, Ecto.Enum, values: [:running, :succeeded, :failed]
    field :event, :map
    field :out, :map
    timestamps()
  end
  def changeset(run, attrs), do: cast(run, attrs, ~w(flow status event out)a)
end
