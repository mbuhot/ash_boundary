import Config

config :exported_vs_internal, ash_domains: [ExportedVsInternal.Catalog]

if config_env() == :test do
  # Quiets Ash's ETS data layer debug logging (record creation, etc.) so `mix test`
  # output stays focused on what this example is actually demonstrating.
  config :logger, level: :warning
end
