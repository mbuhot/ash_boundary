defmodule AshBoundary.Transformers.DeclareBoundary do
  @moduledoc """
  Computes the domain's boundary declaration and installs it on the domain
  module.

  `deps` are taken verbatim from the `boundary` section. They are the user's
  explicit admission of what this domain may reach. AshBoundary computes
  `exports`: the domain module, plus every resource carrying at least one
  domain-level `define`. A resource whose only code interface lives on the
  resource module itself stays internal. This distinction is the basis of the
  whole extension.

  `check` does not come from the DSL either. AshBoundary checks alias
  references by default, because an Ash relationship is an alias reference and
  `boundary` does not check alias references unless asked. See
  `AshBoundary.Declaration.check_opts/0`, which also explains why this
  transformer reads and merges the project-level `check` config.

  Installation goes through `AshBoundary.Declaration.declare/2`. Injecting
  `use Boundary` from a transformer does not work. See that module's docs for
  the reason.

  This transformer runs after `AshBoundary.Transformers.ValidateDomain`.
  ValidateDomain already reports anything `boundary` could not express, with a
  clearer message.
  """

  use Spark.Dsl.Transformer

  alias AshBoundary.Declaration
  alias AshBoundary.Info
  alias Spark.Dsl.Transformer

  @doc false
  @spec after?(module()) :: boolean()
  def after?(_), do: true

  @doc false
  @spec transform(Spark.Dsl.t()) :: {:ok, Spark.Dsl.t()}
  def transform(dsl) do
    Declaration.declare(Transformer.get_persisted(dsl, :module),
      deps: Info.deps(dsl),
      exports: Info.exports(dsl),
      check: Declaration.check_opts(),
      file: Transformer.get_persisted(dsl, :file),
      line: 1
    )

    {:ok, dsl}
  end
end
