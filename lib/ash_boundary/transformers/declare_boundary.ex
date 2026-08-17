defmodule AshBoundary.Transformers.DeclareBoundary do
  @moduledoc """
  Computes the domain's boundary declaration and installs it on the domain
  module. Runs after `AshBoundary.Transformers.ValidateDomain`.
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
