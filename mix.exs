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
      aliases: aliases(),
      # A function reference, not a call: `docs()` references `Spark.Docs`, which is only
      # safe to touch once dependencies are compiled, not while `mix.exs` itself is being
      # evaluated (for example during `mix deps.get`, before `:spark` exists on disk).
      docs: &docs/0,
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
      {:sourceror, "~> 1.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      # `mix spark.cheat_sheets`, which renders the `boundary` DSL section into
      # `documentation/dsls/DSL-AshBoundary.md` for `mix docs` to pick up, is an Igniter
      # task — this is the same mechanism Ash itself uses for its own cheat sheets.
      {:igniter, "~> 0.6", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        {"README.md", title: "Overview"},
        {"guides/decoupling-with-calculations.md", title: "Decoupling via Calculations"},
        {"documentation/dsls/DSL-AshBoundary.md",
         title: "boundary DSL", search_data: Spark.Docs.search_data_for(AshBoundary)}
      ],
      groups_for_extras: [
        Guides: ["guides/decoupling-with-calculations.md"],
        Reference: [~r"documentation/dsls"]
      ],
      # README.md's links to `examples/*` and `LICENSE` are meant for GitHub, where the
      # README is read in place and those relative paths resolve. ExDoc only knows about
      # files listed in `extras` (the four example directories and LICENSE aren't, and
      # shouldn't be — they're not part of the published API docs), so it reports every
      # one of them as a dead link. Same convention Ash itself uses for its own
      # GitHub-native files (CHANGELOG.md, CONTRIBUTING.md).
      skip_undefined_reference_warnings_on: ["README.md"],
      # Five modules total (the extension, `Info`, `Declaration`, and two transformers) is
      # too small a surface for `groups_for_modules` to add anything — a single "Modules"
      # list is already easy to scan. The two transformers are implementation detail behind
      # `AshBoundary.Info`/`AshBoundary.Declaration`, so nesting them under their common
      # `AshBoundary.Transformers` prefix keeps the sidebar's top level to the three modules
      # a user actually needs.
      nest_modules_by_prefix: [AshBoundary.Transformers]
    ]
  end

  defp aliases do
    [
      # `spark.cheat_sheets` regenerates `documentation/dsls/DSL-AshBoundary.md` from the
      # DSL's own schema/docs before every `mix docs` run, so the cheat sheet can never
      # silently drift from the `boundary` section it describes.
      docs: ["spark.cheat_sheets", "docs"],
      "spark.cheat_sheets": "spark.cheat_sheets --extensions AshBoundary"
    ]
  end

  defp package do
    [
      name: "ash_boundary",
      # `guides` and `documentation` ship in the package tarball, not just the git repo,
      # because hexdocs.pm builds docs from exactly what's in the release: an extra
      # missing from here would 404 on hexdocs even though `mix docs` finds it locally.
      files: ~w(lib guides documentation .formatter.exs mix.exs README.md LICENSE),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
