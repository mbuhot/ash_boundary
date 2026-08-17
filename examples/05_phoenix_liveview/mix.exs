defmodule Example.MixProject do
  use Mix.Project

  def project do
    [
      app: :example,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      # `:boundary` goes first, as in examples 1 to 4. A dependency cannot add a compiler to a
      # downstream app's own `:compilers` list. Every app that adopts AshBoundary, or plain
      # `boundary`, must add this entry itself. Without it everything below still compiles
      # cleanly and reports zero violations, including the deliberate ones in `violation/`.
      #
      # `:phoenix_live_view` is the compiler that `mix phx.new` generated. It validates colocated
      # hooks and HEEx. This project keeps it unchanged.
      compilers: [:boundary, :phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Example.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  #
  # `violation/` holds the deliberate violations that this example must prove get caught. The
  # modules use the `ExampleWeb` namespace, so they land inside `ExampleWeb`'s strict boundary.
  # They call `Ash.read!/1`, `Ash.load!/2`, and `Ash.Query.filter/2` directly, and one of them
  # matches an `%Ash.Error.Invalid{}` struct. None of them compiles under boundary enforcement.
  # This project therefore keeps them out of every normal build, with the isolation that example 3
  # uses for `antipattern/` and example 4 uses for its own `violation/`. They compile only under
  # `MIX_ENV=violation`, and the purpose of that env is to fail.
  # `test/example_web/ash_violation_test.exs` shells out to both failing envs and asserts each
  # failure.
  defp elixirc_paths(:violation), do: ["lib", "violation"]
  # `violation_form/` holds one more deliberate failure, in its own env. Its fixture asks the
  # domain for a form builder that does not exist, which fails with an ordinary Elixir
  # undefined-function warning rather than a `boundary` diagnostic. That warning fails the app
  # compile under `--warnings-as-errors`, and `boundary` runs its checks only after a successful
  # app compile. One env therefore cannot show both failure modes in one invocation.
  defp elixirc_paths(:undefined_form), do: ["lib", "violation_form"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Same Ash version as every other example in this repo.
      {:ash, "~> 3.31"},
      {:ash_boundary, path: "../.."},
      # `:ash_phoenix` is a separate OTP application from `:ash`. That separation is the reason
      # the web layer can use `AshPhoenix.Form` while `Ash.read!/1` stays forbidden.
      # `boundary`'s external-dependency check works at application granularity. See
      # `ExampleWeb`.
      {:ash_phoenix, "~> 2.3"},
      {:phoenix, "~> 1.8.9"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
