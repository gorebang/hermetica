import Config

# Tell Ecto which repos this OTP app uses
config :store, ecto_repos: [Store.Repo]

config :store, Store.Repo,
  database: "hermetica_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool_size: 10




# Load per-app base configs (NOT env files)
for file <- Path.wildcard(Path.expand("../apps/*/config/config.exs", __DIR__)) do
  import_config file
end

# Umbrella-wide env override (exactly once)
import_config "#{config_env()}.exs"
