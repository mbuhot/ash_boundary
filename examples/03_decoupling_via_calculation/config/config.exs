import Config

config :decoupling_via_calculation,
  ash_domains: [DecouplingViaCalculation.Customers, DecouplingViaCalculation.Orders]

if config_env() == :antipattern do
  config :decoupling_via_calculation,
    ash_domains: [
      DecouplingViaCalculation.Customers,
      DecouplingViaCalculation.Orders,
      DecouplingViaCalculation.Antipattern.Customers,
      DecouplingViaCalculation.Antipattern.Orders
    ]
end

if config_env() == :test do
  config :logger, level: :warning
end
