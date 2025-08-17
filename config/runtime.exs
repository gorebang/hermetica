import Config

if config_env() in [:dev, :test, :prod] do
  config :store, ecto_repos: [Store.Repo]

  config :store, Store.Repo,
    database: System.get_env("DB_NAME", "hermetica_dev"),
    username: System.get_env("DB_USER", "postgres"),
    password: System.get_env("DB_PASS", "postgres"),
    hostname: System.get_env("DB_HOST", "localhost"),
    pool_size: String.to_integer(System.get_env("DB_POOL", "10"))
end
