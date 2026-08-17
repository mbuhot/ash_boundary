defmodule BasicBoundary.MixProject do
  use Mix.Project

  def project do
    [
      app: :basic_boundary,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      # This is the manual step every app adopting AshBoundary has to take itself:
      # AshBoundary declares boundaries, but only `Mix.Tasks.Compile.Boundary` (added
      # to `:compilers` here) actually enforces them. A dependency cannot add a
      # compiler to its own `:compilers` list on your behalf — see the "Setup" section
      # of the `AshBoundary` moduledoc. Miss this line and every declaration in this
      # example still installs correctly, but no violation is ever reported.
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
