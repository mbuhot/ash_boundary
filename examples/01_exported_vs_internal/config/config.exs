import Config

config :exported_vs_internal, ash_domains: [ExportedVsInternal.Catalog]

if config_env() == :test do
  config :logger, level: :warning
end
