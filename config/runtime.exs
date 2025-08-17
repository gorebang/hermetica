import Config
if config_env() == :prod do
  config :store, ecto_repos: [Store.Repo]
  config :store, Store.Repo,
    database: System.get_env("DB_NAME"),
    username: System.get_env("DB_USER"),
    password: System.get_env("DB_PASS"),
    hostname: System.get_env("DB_HOST"),
    pool_size: String.to_integer(System.get_env("DB_POOL", "10"))
end
