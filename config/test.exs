import Config

config :global_pulse, GlobalPulseWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_that_is_at_least_64_characters_long_for_testing",
  server: false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime