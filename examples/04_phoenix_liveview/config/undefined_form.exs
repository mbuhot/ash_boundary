import Config

config :example, ExampleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4103],
  secret_key_base: String.duplicate("undefinedform", 8),
  server: false

config :logger, level: :warning
