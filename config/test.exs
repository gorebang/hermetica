import Config

config :store, ecto_repos: [Store.Repo]

config :store, Store.Repo,
  username: "postgres",
  password: "postgres",
  database: "hermetica_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
