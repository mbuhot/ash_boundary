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
      # Note what is NOT here: any `boundary: [default: [check: [aliases: true]]]` config.
      # A relationship names a module and calls nothing on it, which `boundary` treats as
      # an alias reference and does not check by default — so catching this example's
      # BEFORE state depends entirely on alias checking being on. AshBoundary turns it on
      # for every domain it declares, so there is nothing to configure here. See the
      # README's "Alias checking is on by default" section.
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
