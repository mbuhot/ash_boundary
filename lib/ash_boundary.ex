defmodule AshBoundary do
  @moduledoc """
  Declares a [`boundary`](https://hex.pm/packages/boundary) for an `Ash.Domain`.
  Only the domain's public API is reachable from outside code.

  `boundary` needs an explicit list of exported modules. Written by hand, that
  list drifts from the domain definition. AshBoundary derives the `boundary`
  declaration from the DSL you already wrote:

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

  The compiler enforces these rules on every build:

    * Outside code may reference `MyApp.Blog.Post`.
    * Outside code may not reference `MyApp.Blog.Comment`.
    * `MyApp.Blog` may reference only `MyApp.Accounts`.

  ## Setup: add the boundary compiler yourself

  AshBoundary declares boundaries. It does not enforce them. Enforcement lives in
  `Mix.Tasks.Compile.Boundary`. Add the compiler to your own `mix.exs`:

      def project do
        [
          app: :my_app,
          compilers: [:boundary] ++ Mix.compilers(),
          # ...
        ]
      end

  Check this setting first if AshBoundary appears to do nothing.

  ## What gets exported

  AshBoundary computes the domain's exports. It never reads a hand-written list.

    * The domain module itself. `boundary` always exports a boundary's root
      module.
    * Every resource with at least one domain-level `define` in the `resources`
      block.

  A resource whose only code interface is declared on the resource module itself
  (`code_interface do ... end` inside `use Ash.Resource`) stays internal.
  Declaring the code interface on the domain makes a resource public.

  Exports do not propagate through relationships. If an exported resource has a
  relationship to a non-exported resource, loading that relationship from
  outside the domain is a violation. Give the relationship a code interface or a
  calculation. See `deps` below.

  ## Relationships are checked, because aliases are checked

  A cross-domain relationship names a module and calls nothing on it:

      belongs_to :customer, Other.Customer

  `boundary` calls this an alias reference. By default, `boundary` does not
  check alias references (`check: [aliases: false]`). Without alias checking, a
  relationship into another domain's non-exported resource would compile with
  no warning.

  AshBoundary turns alias checking on for every domain it declares. AshBoundary
  merges this default with any `boundary: [default: [check: [...]]]` already in
  your `mix.exs`. An explicit `check: [aliases: false]` in your `mix.exs` is
  respected. No extra configuration is needed in the consuming app.

  ## Constraint: resources must be namespaced under the domain

  `Boundary.Mix.Classifier` assigns a module to a boundary by module-name
  nesting alone. Every module under `MyApp.Blog.` belongs to the `MyApp.Blog`
  boundary. `boundary` has no way to assign a module from outside that
  namespace.

  Every resource of a domain extended with AshBoundary must live under the
  domain's own namespace:

      MyApp.Blog                # the domain
      MyApp.Blog.Post           # ok
      MyApp.Blog.Posts.Comment  # ok, nesting can be deeper
      MyApp.Post                # NOT ok

  A resource outside the namespace can never be exported by the domain.
  `boundary` cannot protect that resource either. AshBoundary raises at compile
  time to avoid leaving a resource unguarded. Move resources into the domain's
  namespace before adopting AshBoundary.

  ## Declare `deps` by hand

  `deps` lists the other boundaries this domain may reference. AshBoundary never
  infers this list from existing code. Reviewing every cross-domain dependency
  is the point of `boundary`; inferring the list would rubber-stamp whatever
  coupling already exists.

  Each entry must itself be a boundary: another `Ash.Domain` extended with
  AshBoundary, or a module that calls `use Boundary` directly. Any other entry
  raises a compile-time error.

  An entry is a module, optionally paired with a dependency type from
  `Boundary`.

    * A bare `MyApp.Accounts` (equivalent to `{MyApp.Accounts, :runtime}`)
      permits every kind of reference, at runtime and at compile time.
    * `{MyApp.Accounts, :compile}` narrows this to compile-time references
      only: invocations outside any function, macro invocations, and calls
      from a public macro. An ordinary runtime call to it becomes a violation.
      Use this for a dependency meant only for compilation, such as a macro or
      code-generation dependency. `boundary` has no way to permit a dependency
      at runtime only.

  Declaring a dep grants access to the other domain's exports only: its domain
  module and its publicly-defined resources. Reaching past those is still a
  violation.

  ## Do not also `use Boundary`

  AshBoundary installs the boundary declaration itself. Adding `use Boundary` to
  a domain that is also extended with AshBoundary registers two declarations for
  the same module. Source order decides the winner, so AshBoundary rejects this
  at compile time. To customize something AshBoundary does not expose, drop the
  extension and write the whole declaration by hand.

  ## Structure

    * `AshBoundary.Info` reads the computed `deps` and `exports` back off a
      domain.
    * `AshBoundary.Declaration` is the low-level integration point with
      `boundary`.
    * `AshBoundary.Transformers.ValidateDomain` runs compile-time validation.
    * `AshBoundary.Transformers.DeclareBoundary` computes and installs the
      declaration.
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
