defmodule ExampleWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use ExampleWeb, :controller
      use ExampleWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  # This boundary is what the whole example is about.
  #
  # `type: :strict` is the lever that forbids `Ash.*`. The `boundary` default is
  # `type: :relaxed`. Under that default a boundary can call into any other OTP application
  # freely. That is why Ash resources call `:ash` and `:spark` without friction, and why an
  # unconfigured LiveView can do the same. `:strict` inverts the rule. Every reference into
  # another application must appear in `deps` below. `:ash` does not appear there. So
  # `Ash.read!/1`, `Ash.get!/2`, `Ash.load!/2`, `Ash.Query.filter/2`, and even a
  # `%Ash.Error.Invalid{}` pattern match are compile errors in this namespace. `violation/`
  # holds one module for each case. `test/example_web/ash_violation_test.exs` proves them.
  #
  # This declaration sets no `check: [apps: [...]]`, and that omission is deliberate. The
  # option would be redundant. `Boundary.Checker.check_external_dep?/3` checks an external
  # reference if the boundary is `:strict` or if `check.apps` lists the target application.
  # `:strict` therefore already implies the strongest form of that list. `check.apps` is also
  # not an allowlist. It names the applications to start checking, and those applications then
  # need `deps` entries. `deps` is the allowlist. The README describes the lighter
  # `check: [apps: [:ash, :spark]]` alternative, which most real apps should prefer.
  #
  # `check: [aliases: true]` extends the check to a reference that only names a module without
  # calling it. The `boundary` default is `aliases: false`. AshBoundary turns this option on for
  # every domain it manages, and this boundary matches that posture.
  #
  # The cost of `:strict` is visible below. The list holds about two dozen entries. Several of
  # them, such as `Plug.Builder`, `Phoenix.Config`, and `Phoenix.Transports.*`, are internals
  # that `use Phoenix.Endpoint` and `use Phoenix.Router` reference for you. The README section
  # "What strict costs" states this trade-off.

  # `Phoenix.LiveReloader` comes from `:phoenix_live_reload`, an `only: :dev` dependency. The
  # module exists in `:dev` and does not exist in `:test` or `:prod`. An unconditional entry
  # fails those two envs with `unknown boundary Phoenix.LiveReloader is listed as a dependency`.
  # The options for `use Boundary` are an ordinary compile-time expression, and each env is a
  # separate compilation. An env-scoped dep therefore gets an env-scoped entry, the same
  # treatment as any other env-specific Mix configuration.
  @dev_only_deps if Mix.env() == :dev, do: [Phoenix.LiveReloader], else: []

  # The domain and the form library. `Example` is the only in-app boundary that the web layer can
  # touch. `AshPhoenix.Form` is a separate OTP application from `:ash`. That separation is why the
  # app-level check can tell the two apart, and it is what lets this layer use forms without
  # `:ash`. The web layer builds each form through `Example.form_to_create_post/1`, so it needs
  # `AshPhoenix.Form` only for `validate/2` and `submit/2` on the struct the domain returns.
  @domain_deps [Example, AshPhoenix.Form]

  # Everything the `mix phx.new` web tier references. No entry here is discretionary. Each one
  # is present because a real reference in `lib/example_web/` failed without it.
  @framework_deps [
    Logger,
    Phoenix,
    Phoenix.Channel,
    Phoenix.CodeReloader,
    Phoenix.Component,
    Phoenix.Config,
    Phoenix.Controller,
    Phoenix.Endpoint,
    Phoenix.Flash,
    Phoenix.HTML,
    Phoenix.LiveComponent,
    Phoenix.LiveView,
    Phoenix.PubSub,
    Phoenix.Router,
    Phoenix.Template,
    Phoenix.Transports.LongPoll,
    Phoenix.Transports.WebSocket,
    Phoenix.VerifiedRoutes,
    Plug,
    Plug.Builder,
    Plug.Conn,
    Plug.Debugger,
    Plug.Head,
    Plug.MethodOverride,
    Plug.Parsers,
    Plug.RequestId,
    Plug.Session,
    Plug.Static,
    Plug.Telemetry,
    Telemetry.Metrics
  ]

  use Boundary,
    type: :strict,
    check: [aliases: true],
    # `{Mix, :compile}` covers the `Mix.env()` call above. `:strict` checks that call like any
    # other reference into another application. A compile-time-only entry keeps a runtime
    # `Mix.env()` call in a LiveView a violation. A runtime call to Mix is unsafe in a release.
    # `Boundary`'s docs recommend this narrowing for `:mix`.
    #
    # Write this entry inline. Do not move it into a module attribute beside the groups above.
    # `boundary`'s tracer skips an alias reference inside the declaration it generates. The guard
    # is `unless env.function == {:boundary, 1}` in `Mix.Tasks.Compile.Boundary.trace/2`. An
    # alias in a module attribute is an ordinary reference, and the check applies to it. For a
    # compile-time-only dep that check fails.
    #
    # The four test-only entries below follow the same rule. `test/support/conn_case.ex` compiles
    # into this boundary in `:test` only, and it references those four modules.
    # `ExUnit.CaseTemplate` exists in every env, so an attribute reports a forbidden reference in
    # `:dev` and `:prod`, where the attribute value is `[]`. `@dev_only_deps` escapes that trap
    # by accident: `Phoenix.LiveReloader` does not exist outside `:dev`, and `boundary` treats a
    # reference to a module it cannot find as an in-app reference. The `Example` and
    # `Phoenix.*` groups are safe in attributes, because they are full runtime deps.
    deps:
      [{Mix, :compile}] ++
        @domain_deps ++
        @framework_deps ++
        @dev_only_deps ++
        if(Mix.env() == :test,
          do: [ExUnit.Callbacks, ExUnit.CaseTemplate, Phoenix.ConnTest, Phoenix.LiveViewTest],
          else: []
        ),
    # `Example.Application` starts both of these modules. No other module outside this namespace
    # needs to name anything under `ExampleWeb.*`.
    exports: [Endpoint, Telemetry]

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import ExampleWeb.CoreComponents

      # Common modules used in templates
      alias Phoenix.LiveView.JS
      alias ExampleWeb.Layouts

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: ExampleWeb.Endpoint,
        router: ExampleWeb.Router,
        statics: ExampleWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
