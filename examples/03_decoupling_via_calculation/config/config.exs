import Config

config :decoupling_via_calculation,
  ash_domains: [DecouplingViaCalculation.Customers, DecouplingViaCalculation.Orders]

if config_env() == :antipattern do
  # The `antipattern/` build (see mix.exs) adds the coupled BEFORE-state domains on top
  # of the shipped ones. It exists only to be compiled and fail.
  config :decoupling_via_calculation,
    ash_domains: [
      DecouplingViaCalculation.Customers,
      DecouplingViaCalculation.Orders,
      DecouplingViaCalculation.Antipattern.Customers,
      DecouplingViaCalculation.Antipattern.Orders
    ]
end

if config_env() == :test do
  # Quiets Ash's ETS data layer debug logging (record creation, etc.) so `mix test`
  # output stays focused on what this example is actually demonstrating.
  config :logger, level: :warning
end
