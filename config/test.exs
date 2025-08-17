# config/test.exs
import Config

config :store, ecto_repos: [Store.Repo]

config :store, Store.Repo,
  database: "hermetica_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
