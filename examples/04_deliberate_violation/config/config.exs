import Config

config :deliberate_violation,
  ash_domains: [DeliberateViolation.Accounting, DeliberateViolation.Billing]

if config_env() == :violation do
  config :deliberate_violation,
    ash_domains: [
      DeliberateViolation.Accounting,
      DeliberateViolation.Billing,
      DeliberateViolation.Violation.Billing
    ]
end

if config_env() == :test do
  config :logger, level: :warning
end
