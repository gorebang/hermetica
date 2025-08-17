# config/dev.exs (umbrella root)
import Config

config :store, ecto_repos: [Store.Repo]

config :store, Store.Repo,
  database: "hermetica_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool_size: 10
