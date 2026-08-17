import Config

config :exported_vs_internal, ash_domains: [Catalog, Storefront]

if config_env() == :test do
  config :logger, level: :warning
end
