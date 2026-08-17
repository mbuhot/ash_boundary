import Config

# The `:undefined_form` env exists for one purpose: to compile `violation_form/` (see `mix.exs`'s
# `elixirc_paths/1`) and fail. It is separate from the `:violation` env for a concrete reason. Its
# fixture fails with an ordinary Elixir undefined-function warning, and that warning fails the app
# compile under `--warnings-as-errors`. `boundary` runs its own checks only after a successful app
# compile, so a single env cannot demonstrate both failure modes in one invocation.
config :example, ExampleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4103],
  secret_key_base: String.duplicate("undefinedform", 8),
  server: false

config :logger, level: :warning
