import Config

config :basic_boundary, ash_domains: [BasicBoundary.Blog]

if config_env() == :test do
  config :logger, level: :warning
end
