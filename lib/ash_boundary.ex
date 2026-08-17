defmodule AshBoundary do
  @moduledoc """
  Declares a [`boundary`](https://hex.pm/packages/boundary) for an `Ash.Domain`, so that
  only the domain's intentional public API is reachable from outside code.

  Ash already draws a line around a domain: the resources it owns, and the code interface
  it exposes for them. Nothing enforces that line — any module in the app can reach into
  any resource, and accidental cross-domain coupling only shows up much later, as a
  refactor that cannot be done. `boundary` can enforce exactly this kind of line, but
  wants the module list spelled out by hand, which immediately drifts from the domain.

  AshBoundary connects the two. Add it as an extension and the domain's `boundary`
  declaration is derived from the DSL you already wrote:

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

  From outside `MyApp.Blog`, `MyApp.Blog.Post` may now be referenced and
  `MyApp.Blog.Comment` may not, and `MyApp.Blog` itself may only reference
  `MyApp.Accounts` — checked by the compiler, on every build.

  ## Setup: you must add the boundary compiler yourself

  **AshBoundary declares boundaries. It cannot enforce them.** Enforcement lives entirely
  in `Mix.Tasks.Compile.Boundary`, and a Mix compiler can only be enabled by the project
  it runs in — a dependency cannot add itself to a downstream app's `:compilers`. So the
  app using AshBoundary has to edit its own `mix.exs`:

      def project do
        [
          app: :my_app,
          compilers: [:boundary] ++ Mix.compilers(),
          # ...
        ]
      end

  Miss this step and there is no error to notice: everything compiles, every declaration
  is installed correctly, and not one violation is ever reported. If AshBoundary appears
  to be doing nothing, check this first.

  ## What gets exported

  The domain's exports are computed, never listed by hand:

    * the domain module itself — its code interface is the public API, and `boundary`
      always exports a boundary's root module, and
    * every resource with at least one **domain-level** `define` in the `resources`
      block.

  A resource whose only code interface is declared on the resource module itself
  (`code_interface do ... end` inside `use Ash.Resource`) is deliberately *not* exported.
  Declaring the code interface on the domain is the act of making a resource public.

  There is no transitive propagation. If an exported resource has a relationship to a
  non-exported one, loading that relationship from outside the domain is a real
  violation, and the signal that the relationship wants a code interface or a
  calculation instead. See `deps` below.

  ## Relationships are checked, because aliases are checked

  A cross-domain relationship names a module and calls nothing on it:

      belongs_to :customer, Other.Customer

  To `boundary` that is an *alias reference*, and `boundary` does not check alias
  references unless asked to — `check: [aliases: false]` is its default. Left alone, that
  would make the single most important case AshBoundary exists to catch the one case it
  silently missed: a relationship reaching into another domain's non-exported resource
  would compile with no warning at all.

  So AshBoundary turns alias checking **on** for every domain it declares. This is a
  default, not an override: any `boundary: [default: [check: [...]]]` in your `mix.exs` is
  merged with, not replaced by, and an explicit `check: [aliases: false]` there is
  respected. Nothing extra is needed in the consuming app.

  ## Constraint: resources must be namespaced under the domain

  `Boundary.Mix.Classifier` assigns a module to a boundary purely by module-name nesting.
  Everything under `MyApp.Blog.` belongs to the `MyApp.Blog` boundary, and nothing else
  can — there is no way to say "this module over here is also mine".

  So every resource of a domain extended with AshBoundary must live under the domain's
  own namespace:

      MyApp.Blog                # the domain
      MyApp.Blog.Post           # ok
      MyApp.Blog.Posts.Comment  # ok, nesting can be deeper
      MyApp.Post                # NOT ok

  A resource outside the namespace could never be exported by the domain, and would not
  be protected by it either, so AshBoundary raises at compile time rather than leaving a
  resource silently unguarded. Apps that keep resources in a flat or separate namespace
  need to move them before adopting AshBoundary.

  ## `deps` is declared, not inferred

  `deps` lists the other boundaries this domain is allowed to reference at all. It is
  deliberately manual: forcing an explicit, reviewable acknowledgment of every
  cross-domain dependency is the entire point of `boundary`, and inferring the list from
  existing references would just rubber-stamp whatever coupling already exists.

  Each entry must itself be a boundary — another `Ash.Domain` extended with AshBoundary,
  or any module that calls `use Boundary` directly. Anything else is a compile-time
  error, rather than a confusing `boundary` diagnostic later.

  Entries are modules, optionally paired with a dependency type matching `Boundary`'s
  own. A bare `MyApp.Accounts` (equivalently `{MyApp.Accounts, :runtime}`) is what nearly
  every cross-domain dependency wants: it permits *every* kind of reference, at runtime
  and at compile time alike.

  `{MyApp.Accounts, :compile}` is a **narrowing**, not a widening. It permits compile-time
  references only — invocations outside any function, macro invocations, and calls made
  from a public macro — and turns an ordinary runtime call into a violation. Reach for it
  in the rare case where a domain is only meant to be used during compilation, such as a
  macro or code-generation dependency, and you want an accidental runtime call to be
  rejected. `boundary` offers no way to permit a dependency at runtime *only*: anything
  allowed at runtime is allowed at compile time too.

  Note that declaring a dep grants access to the other domain's *exports* only — its
  domain module and its publicly-defined resources. Reaching past those is still a
  violation.

  ## Do not also `use Boundary`

  AshBoundary installs the boundary declaration itself. Writing `use Boundary` on a
  domain that is also extended with AshBoundary means two mechanisms racing to define
  the same declaration, with the winner decided by source order, so it is rejected at
  compile time. To customise something AshBoundary does not expose, drop the extension
  and hand-write the whole declaration.

  ## Structure

    * `AshBoundary.Info` — read the computed `deps` and `exports` back off a domain.
    * `AshBoundary.Declaration` — the low-level integration point with `boundary`.
    * `AshBoundary.Transformers.ValidateDomain` — compile-time validation.
    * `AshBoundary.Transformers.DeclareBoundary` — computes and installs the declaration.
  """

  @deps_type {:or, [:module, {:tuple, [:module, {:one_of, [:compile, :runtime]}]}]}

  @boundary %Spark.Dsl.Section{
    name: :boundary,
    describe: """
    Configures the `boundary` declared for this domain.

    The section is optional: a domain extended with AshBoundary declares a boundary with
    no deps even if the section is absent, which is the strictest and most useful
    default. Add it to admit dependencies on other domains.
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
        Other boundaries this domain is allowed to reference.

        Each entry must be a module that declares a boundary of its own — another
        `Ash.Domain` extended with `AshBoundary`, or a module using `Boundary` directly.
        A bare module is equivalent to `{module, :runtime}` and permits references of
        every kind. `{module, :compile}` narrows that to compile-time references only,
        so an ordinary runtime call to it becomes a violation.
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
