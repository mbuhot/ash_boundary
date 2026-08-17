defmodule AshBoundary.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/mbuhot/ash_boundary"
  @description "Boundary declarations for Ash domains, built on top of `boundary`."

  def project do
    [
      app: :ash_boundary,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description: @description,
      package: package(),
      source_url: @source_url,
      homepage_url: @source_url,
      dialyzer: [
        # `:boundary` is a `runtime: false` dep, so it is not in the PLT by
        # default and every call AshBoundary makes into it would be reported as
        # an unknown function.
        plt_add_apps: [:mix, :ex_unit, :boundary],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.31"},
      {:spark, "~> 2.7"},
      {:boundary, "~> 0.10.4", runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      # `mix spark.formatter`, which regenerates the `boundary` DSL's
      # `locals_without_parens` in `.formatter.exs`, only exists when Sourceror is
      # available. Nothing at runtime needs it.
      {:sourceror, "~> 1.2", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      name: "ash_boundary",
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
