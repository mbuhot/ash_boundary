defmodule ExportedVsInternal.MixProject do
  use Mix.Project

  def project do
    [
      app: :exported_vs_internal,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      # See examples/01_basic_boundary's README: a dependency cannot add a compiler to
      # a downstream app's own :compilers list, so every app adopting AshBoundary adds
      # this line itself. Miss it and everything below still compiles and installs
      # correctly, with zero violations ever reported.
      compilers: [:boundary] ++ Mix.compilers(),
      deps: deps()
    ]
  end

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
