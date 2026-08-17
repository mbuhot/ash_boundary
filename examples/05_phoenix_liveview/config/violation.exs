import Config

config :example, ExampleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4102],
  secret_key_base: String.duplicate("violation", 8),
  server: false

config :logger, level: :warning
