import Config

config :global_pulse,
  ecto_repos: [GlobalPulse.Repo]

config :global_pulse, GlobalPulseWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: GlobalPulseWeb.ErrorHTML, json: GlobalPulseWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: GlobalPulse.PubSub,
  live_view: [signing_salt: "QqXBsF8Y"]

config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.3.0",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"