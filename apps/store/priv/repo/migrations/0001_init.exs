# apps/store/priv/repo/migrations/0001_init.exs
defmodule Store.Repo.Migrations.Init do
  use Ecto.Migration

  def change do
    create table(:runs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :flow, :string, null: false
      add :status, :string, null: false
      add :event, :map
      add :out, :map
      timestamps()
    end

    create table(:step_runs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :run_id, :uuid, null: false
      add :step, :string, null: false
      add :status, :string, null: false
      add :input, :map
      add :output, :map
      add :error, :map
      timestamps()
    end

    create index(:step_runs, [:run_id])
  end
end
