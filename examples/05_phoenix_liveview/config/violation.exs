import Config

# The `:violation` env exists for one purpose: to compile `violation/` (see `mix.exs`'s
# `elixirc_paths/1`) and fail. It never starts the endpoint, so this file only needs to
# supply enough configuration for compilation to reach the boundary checker.
config :example, ExampleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4102],
  secret_key_base: String.duplicate("violation", 8),
  server: false

config :logger, level: :warning
