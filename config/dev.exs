import Config

config :global_pulse, GlobalPulse.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "global_pulse_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :global_pulse, GlobalPulseWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "rOPmYvXvQVxBqxXzplzJcKynZRVNcXDNbvlyPBQkSzRiYVPzIlAViKfKkHxNx5+x",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]

config :global_pulse, GlobalPulseWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/global_pulse_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :global_pulse, dev_routes: true

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime