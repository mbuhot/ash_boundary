defmodule AshBoundary do
  @moduledoc """
  Declares a [`boundary`](https://hex.pm/packages/boundary) for an `Ash.Domain`.
  Only the domain's public API is reachable from outside code.

  AshBoundary derives the `boundary` declaration from the domain DSL:

      defmodule MyApp.Blog do
        use Ash.Domain, extensions: [AshBoundary]

        boundary do
          deps [MyApp.Accounts]
          exports [MyApp.Blog.PostStatus]
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
    * Each module named in `exports` is public.
    * All other modules in the domain's namespace are internal.
    * Referencing another domain requires an explicit `boundary` dep.

  AshBoundary sets `check: [aliases: true]` so `boundary` reports any cross-domain relationships as violations.

  ## Read-only relationships

  A relationship into another domain's resource needs a `deps` entry for that
  domain. With `allow_read_only_relationships? true`, a relationship declaring
  `writable?: false` does not, and the target must still be exported by the
  domain that owns it:

      defmodule MyApp.Shipping do
        use Ash.Domain, extensions: [AshBoundary]

        boundary do
          allow_read_only_relationships? true
        end

        resources do
          resource MyApp.Shipping.Shipment do
            define :get_shipment, action: :read
          end
        end
      end

  A two-way relationship declares the dep on the writable side only, so the two
  domains do not depend on each other.
  """

  @deps_type {:or, [:module, {:tuple, [:module, {:one_of, [:compile, :runtime]}]}]}

  @boundary %Spark.Dsl.Section{
    name: :boundary,
    describe: """
    Configures the `boundary` declared for this domain.

    This section is optional. A domain with no `boundary` section declares a
    boundary with zero deps, which is the strictest default. Add the section to
    declare dependencies on other domains, or to export a public module that is
    not a resource.
    """,
    examples: [
      """
      boundary do
        deps [MyApp.Accounts, {MyApp.Codegen, :compile}]
        exports [MyApp.Blog.PostStatus]
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
      ],
      exports: [
        type: {:list, :module},
        default: [],
        doc: """
        Public modules of this domain that are not resources.

        An `Ash.Type.Enum` named in an exported resource's attribute types is
        the usual case: outside code has to name it, so it belongs in the
        domain's API. Each module must be nested under the domain's namespace.

        A resource of this domain is rejected here. Resource exports come from
        `resources`, where a domain-level `define` makes a resource public.
        """
      ],
      allow_read_only_relationships?: [
        type: :boolean,
        default: false,
        doc: """
        Whether this domain's resources may name another domain's resource in a
        read-only relationship without a `deps` entry for that domain.

        A relationship qualifies when it declares `writable?: false`, which is
        what stops it creating or updating the resource on the other side. The
        target still has to be exported by the domain that owns it.

        Set this on the read-only side of a two-way relationship. The writable
        side keeps its `deps` entry, so only one of the two directions is a
        dependency and the pair is not a cycle.

        The exemption covers a target module rather than one relationship, so a
        domain declaring both a read-only and a writable relationship to the
        same resource is rejected at compile time. A target is read-only from a
        domain or it is not.
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
