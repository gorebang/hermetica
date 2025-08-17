# mix.exs (umbrella root)
defmodule Hermetica.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
        aliases: [
          "ecto.setup": [
            "cmd --app store mix deps.get",
            "cmd --app store MIX_ENV=$MIX_ENV mix ecto.create -r Store.Repo",
            "cmd --app store MIX_ENV=$MIX_ENV mix ecto.migrate -r Store.Repo"
          ],
            "db.setup":   ["ecto.create -r Store.Repo", "ecto.migrate -r Store.Repo"],
            "db.create":  ["ecto.create -r Store.Repo"],
            "db.migrate": ["ecto.migrate -r Store.Repo"]
          # "ecto.create": [
          #   "cmd --app store MIX_ENV=$MIX_ENV mix ecto.create -r Store.Repo"
          # ],
          # "ecto.migrate": [
          #   "cmd --app store MIX_ENV=$MIX_ENV mix ecto.migrate -r Store.Repo"
          # ]
        ]
    ]
  end
end
