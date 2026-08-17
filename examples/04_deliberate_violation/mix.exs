defmodule DeliberateViolation.MixProject do
  use Mix.Project

  def project do
    [
      app: :deliberate_violation,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      # See examples/01_basic_boundary's README: a dependency cannot add a compiler to
      # a downstream app's own :compilers list, so every app adopting AshBoundary adds
      # this line itself. Miss it and everything below still compiles and installs
      # correctly, with zero violations ever reported.
      compilers: [:boundary] ++ Mix.compilers(),
      # Note what is NOT here: any `boundary: [default: [check: [aliases: true]]]`
      # config. AshBoundary turns alias checking on for every domain it declares, which
      # is what makes the `belongs_to` relationship in `violation/billing/invoice.ex`
      # a caught violation rather than one that silently slips through — see the
      # README's "Two ways in" section.
      deps: deps()
    ]
  end

  # `violation/` holds the DELIBERATE violation this example exists to demonstrate: a
  # sibling domain reaching into Accounting's internal LedgerEntry resource, both by a
  # plain function call and by a genuine Ash relationship. It does not compile under
  # boundary enforcement, so it is kept out of every normal build (the same isolation
  # example 3 uses for its `antipattern/` tree) and compiled only under
  # `MIX_ENV=violation`, whose entire purpose is to fail. See the README and
  # `test/deliberate_violation/violation_test.exs`, which shells out to exactly that
  # invocation and asserts it fails in the expected way — this is not left as a manual
  # README-only exercise.
  defp elixirc_paths(:violation), do: ["lib", "violation"]
  defp elixirc_paths(_env), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ash, "~> 3.31"},
      {:ash_boundary, path: "../.."}
    ]
  end
end
