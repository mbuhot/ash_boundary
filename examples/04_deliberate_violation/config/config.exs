import Config

config :deliberate_violation,
  ash_domains: [DeliberateViolation.Accounting, DeliberateViolation.Billing]

if config_env() == :violation do
  # The `violation/` build (see mix.exs) adds the deliberately-coupled bad domain on top
  # of the shipped ones. It exists only to be compiled and fail.
  config :deliberate_violation,
    ash_domains: [
      DeliberateViolation.Accounting,
      DeliberateViolation.Billing,
      DeliberateViolation.Violation.Billing
    ]
end

if config_env() == :test do
  # Quiets Ash's ETS data layer debug logging (record creation, etc.) so `mix test`
  # output stays focused on what this example is actually demonstrating.
  config :logger, level: :warning
end
