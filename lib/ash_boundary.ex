defmodule AshBoundary do
  @moduledoc """
  Declares a [`boundary`](https://hex.pm/packages/boundary) for an `Ash.Domain`.
  Only the domain's public API is reachable from outside code.

  AshBoundary derives the `boundary` declaration from the domain DSL:

      defmodule MyApp.Blog do
        use Ash.Domain, extensions: [AshBoundary]

        boundary do
          deps [MyApp.Accounts]
        end

        resources do
          resource MyApp.Blog.Post do
            define :get_post, action: :read
            define :update_post, action: :update
          end

          resource MyApp.Blog.Comment do
            # no domain-level define, so it stays internal
          end
        end
      end

  ## Setup

  Add the `:boundary` compiler to your project configuration:

      def project do
        [
          app: :my_app,
          compilers: [:boundary] ++ Mix.compilers(),
          # ...
        ]
      end

  ## What gets exported

    * The domain module is public.
    * Each resource that exposes a code interface in the domain is public.
    * All other modules in the domain's namespace are internal.
    * Referencing another domain requires an explicit `boundary` dep.

  A resource whose only code interface is declared on the resource module itself
  (`code_interface do ... end` inside `use Ash.Resource`) stays internal.

  A `define` publishes the whole resource module, not only the actions it names:
  `boundary` exports modules, not functions. Outside code can call any public
  function on an exported resource, including the functions from its own
  `code_interface` block. There is no way to export one action and withhold
  another on the same module.

  Exports do not propagate through relationships. If an exported resource has a
  relationship to a non-exported resource, loading that relationship from
  outside the domain is a violation.

  AshBoundary sets `check: [aliases: true]`, so a cross-domain relationship is
  checked like any other reference.

  Resources must be namespaced under their domain. AshBoundary raises at compile
  time otherwise, since `boundary` can neither export nor protect a module
  outside the namespace.
  """

  @deps_type {:or, [:module, {:tuple, [:module, {:one_of, [:compile, :runtime]}]}]}

  @boundary %Spark.Dsl.Section{
    name: :boundary,
    describe: """
    Configures the `boundary` declared for this domain.

    This section is optional. A domain with no `boundary` section declares a
    boundary with zero deps, which is the strictest default. Add the section to
    declare dependencies on other domains.
    """,
    examples: [
      """
      boundary do
        deps [MyApp.Accounts, {MyApp.Codegen, :compile}]
      end
      """
    ],
    schema: [
      deps: [
        type: {:list, @deps_type},
        default: [],
        doc: """
        The other boundaries this domain can reference.

        Each entry must be a module that declares a boundary of its own: an
        `Ash.Domain` extended with `AshBoundary`, or a module that calls
        `use Boundary`. A bare module is equivalent to `{module, :runtime}` and
        permits each kind of reference. `{module, :compile}` permits
        compile-time references only, so a runtime call to that boundary
        becomes a violation.
        """
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@boundary],
    transformers: [
      AshBoundary.Transformers.ValidateDomain,
      AshBoundary.Transformers.DeclareBoundary
    ]
end
