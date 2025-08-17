import Config

# Tell Ecto which repos this OTP app uses
config :store, ecto_repos: [Store.Repo]

config :store, Store.Repo,
  database: "hermetica_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool_size: 10

  import_config "#{config_env()}.exs"
