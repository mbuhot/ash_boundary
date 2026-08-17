defmodule ExportedVsInternal.MixProject do
  use Mix.Project

  def project do
    [
      app: :exported_vs_internal,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
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
