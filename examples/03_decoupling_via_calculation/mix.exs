defmodule DecouplingViaCalculation.MixProject do
  use Mix.Project

  def project do
    [
      app: :decoupling_via_calculation,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      # See examples/01_basic_boundary's README: a dependency cannot add a compiler to
      # a downstream app's own :compilers list, so every app adopting AshBoundary adds
      # this line itself. Miss it and everything below still compiles and installs
      # correctly, with zero violations ever reported.
      compilers: [:boundary] ++ Mix.compilers(),
      # REQUIRED for this example, and the one setting a real app replacing cross-domain
      # relationships needs to know about. `boundary` does not check plain alias
      # references (`Some.Module` appearing as a value, with nothing called on it) unless
      # you opt in — `check: [aliases: false]` is its default. An Ash relationship is
      # exactly that kind of reference:
      #
      #     belongs_to :customer, OtherDomain.Customer
      #
      # names the other domain's resource module and calls nothing on it, so with
      # `boundary`'s defaults a cross-domain relationship is invisible to the compiler and
      # this example's BEFORE state compiles quietly. `boundary` applies this project-level
      # default to every boundary in the app, including the ones `AshBoundary` declares.
      # See the README's "You have to ask boundary to check aliases" section.
      boundary: [default: [check: [aliases: true]]],
      deps: deps()
    ]
  end

  # The `antipattern/` directory holds the BEFORE state this example teaches against: a
  # direct cross-domain relationship, which is a boundary violation and therefore does
  # not compile. It is deliberately kept out of every normal build so that this
  # example's own gate (`mix compile --warnings-as-errors && mix test`) stays green, and
  # is compiled only under `MIX_ENV=antipattern`, whose entire purpose is to fail. See
  # the README's "Reproducing the BEFORE state yourself" section.
  defp elixirc_paths(:antipattern), do: ["lib", "antipattern"]
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
