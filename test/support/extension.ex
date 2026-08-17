defmodule AshBoundary.Test.Extension do
  @moduledoc """
  A deliberately minimal stand-in for the real `AshBoundary` DSL extension.

  It exists to exercise `AshBoundary.Declaration` end to end against a real
  `Ash.Domain`: a `boundary do deps [...] end` section, and a transformer that
  computes exports from the domain's resource references. The full extension —
  option docs, verifier, cheat sheets — is a later unit; when it lands, this
  transformer's body should move into `lib/` rather than being reimplemented.
  """

  @boundary %Spark.Dsl.Section{
    name: :boundary,
    describe: "Declares the boundary for this domain.",
    schema: [
      deps: [
        type: {:list, :atom},
        default: [],
        doc: "Other boundaries this domain is allowed to depend on."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@boundary],
    transformers: [AshBoundary.Test.Extension.Transformer]
end

defmodule AshBoundary.Test.Extension.Transformer do
  @moduledoc """
  Computes the boundary declaration for a domain and installs it.

  Exports are the resources carrying at least one domain-level `define`; resources
  whose only code interface lives on the resource module itself stay internal. The
  domain module is exported implicitly by `boundary` and so is not listed.
  """

  use Spark.Dsl.Transformer

  alias Ash.Domain.Info
  alias Spark.Dsl.Transformer

  @doc false
  @spec after?(module()) :: boolean()
  def after?(_), do: true

  @doc false
  @spec transform(Spark.Dsl.t()) :: {:ok, Spark.Dsl.t()}
  def transform(dsl) do
    module = Transformer.get_persisted(dsl, :module)

    exports =
      dsl
      |> Info.resource_references()
      |> Enum.filter(&(&1.definitions != []))
      |> Enum.map(& &1.resource)

    AshBoundary.Declaration.declare(module,
      deps: Transformer.get_option(dsl, [:boundary], :deps, []),
      exports: exports,
      file: Transformer.get_persisted(dsl, :file),
      line: 1
    )

    {:ok, dsl}
  end
end
