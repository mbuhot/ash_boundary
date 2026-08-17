defmodule DecouplingViaCalculation.MixProject do
  use Mix.Project

  def project do
    [
      app: :decoupling_via_calculation,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:boundary] ++ Mix.compilers(),
      deps: deps()
    ]
  end

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
