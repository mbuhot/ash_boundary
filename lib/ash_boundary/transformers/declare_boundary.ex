defmodule AshBoundary.Transformers.DeclareBoundary do
  @moduledoc """
  Computes the domain's boundary declaration and installs it on the domain module.

  `deps` are taken verbatim from the `boundary` section — they are the user's explicit
  admission of what this domain may reach. `exports` are computed: the domain module,
  plus every resource carrying at least one domain-level `define`. A resource whose only
  code interface lives on the resource module itself stays internal, which is the
  distinction the whole extension rests on.

  `check` is not taken from the DSL either. Alias references are checked by default,
  because an Ash relationship *is* an alias reference and `boundary` does not check those
  unless asked — see `AshBoundary.Declaration.check_opts/0`, which also explains why the
  project-level `check` config has to be read and merged here rather than replaced.

  Installation goes through `AshBoundary.Declaration.declare/2` rather than injecting
  `use Boundary`, which cannot work from a transformer — see that module's docs.

  Runs after `AshBoundary.Transformers.ValidateDomain`, so anything `boundary` could not
  express has already been reported with a better message than it would produce.
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
