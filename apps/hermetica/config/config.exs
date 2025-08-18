import Config

config :hermetica, :flows, [Hermetica.Flows.Example]

import_config "#{config_env()}.exs"
