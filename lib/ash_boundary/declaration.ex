defmodule AshBoundary.Declaration do
  @moduledoc """
  Installs a [`boundary`](https://hex.pm/packages/boundary) declaration onto a
  module that is currently being compiled.

  This is the low-level integration point between AshBoundary and the
  `boundary` library. A Spark transformer computes the `deps` and `exports`
  lists and calls `declare/2`. After this call, `boundary` treats the module
  exactly as if it had called `use Boundary, deps: ..., exports: ...` by hand.

  ## Why not inject `use Boundary`?

  `use Boundary` expands to code that stores the options in module attributes
  and registers a `@before_compile Boundary.Definition` hook. This hook writes
  the persisted `Boundary` module attribute that the rest of the library reads.

  Spark runs its transformers from inside the DSL module's own `@before_compile`
  hook. Elixir snapshots the list of `@before_compile` callbacks before invoking
  any of them. Injecting `use Boundary` at that point registers a hook that
  Elixir never invokes. The module compiles cleanly. It ends up with no
  boundary at all. This failure produces no warning and no error.

  `declare/2` reproduces the end state of
  `Boundary.Definition.__before_compile__/1` directly, with plain function
  calls:

    * A persisted `Boundary` module attribute holding the definition map. This
      is what `Boundary.Definition` reads back out of a compiled module.
    * An entry in `Boundary.Mix.CompilerState`, the in-memory cache
      `Mix.Tasks.Compile.Boundary` consults during a compilation run. Skipping
      this entry is not optional. When the cache exists but has no entry for a
      module, `boundary` treats that module as not being a boundary at all.

  Function calls avoid a second problem. `boundary`'s compiler tracer sees
  anything injected into the consuming module. An injected `use Boundary`
  would record spurious cross-boundary references from the domain to every
  module named in it. Calls made from here are made by already-compiled
  AshBoundary code, so the tracer never sees them.

  ## Exports are relative to the boundary root

  `boundary` treats every entry in `exports` as a name relative to the
  boundary module. `use Boundary, exports: [Post]` on `MyApp.Blog` exports
  `MyApp.Blog.Post`. Passing the fully qualified `MyApp.Blog.Post` exports
  `MyApp.Blog.MyApp.Blog.Post`, a module that does not exist. `boundary`
  reports this as an `unknown_export` error.

  `declare/2` takes fully qualified module names and converts them, so callers
  never handle this conversion. See `relative_exports/2`.

  `boundary` always exports the boundary module itself. It does not need to
  appear in `exports`, and `declare/2` drops it if passed.

  ## Consuming apps must add the boundary compiler themselves

  Declaring a boundary does not enforce one. Enforcement lives entirely in
  `Mix.Tasks.Compile.Boundary`. A dependency cannot add itself to a downstream
  app's `:compilers` list. Every app using AshBoundary must edit its own
  `mix.exs`:

      def project do
        [
          compilers: [:boundary] ++ Mix.compilers(),
          # ...
        ]
      end

  If the `:compilers` list does not include `:boundary`, the build reports no
  violations, even though the declarations still install correctly.
  """

  alias Boundary.Mix.CompilerState

  @typedoc """
  The definition map `boundary` stores in the persisted `Boundary` module attribute.
  """
  @type t :: %{
          opts: keyword(),
          pos: %{file: String.t() | nil, line: pos_integer() | nil},
          app: atom(),
          protocol?: boolean(),
          mix_task?: boolean()
        }

  @doc """
  Declares `module` as a boundary, as if it had called `use Boundary`.

  Call this while `module` is still being compiled. A Spark transformer runs at
  that point.

  Supported options:

    * `:exports` - fully qualified modules to export. Converted to the relative
      form `boundary` expects.
    * `:file` / `:line` - the source position used in `boundary`'s error messages.
    * Every other option passes through to `boundary` untouched, so `:deps`,
      `:type`, `:check`, `:top_level?` and `:dirty_xrefs` all work as documented
      by `Boundary`.

  This function applies no defaults, `:check` included. `check_opts/0` explains
  what AshBoundary passes for a domain.

  Raises `ArgumentError` if an export lives outside the boundary's namespace.
  `boundary` has no way to express that export.
  """
  @spec declare(module(), keyword()) :: :ok
  def declare(module, opts) when is_atom(module) and is_list(opts) do
    if not Module.open?(module) do
      raise ArgumentError,
            "#{inspect(__MODULE__)}.declare/2 must be called while #{inspect(module)} is " <>
              "still being compiled, for example from a Spark transformer"
    end

    {exports, opts} = Keyword.pop(opts, :exports, [])
    {file, opts} = Keyword.pop(opts, :file)
    {line, opts} = Keyword.pop(opts, :line)

    exports =
      case relative_exports(module, exports) do
        {:ok, exports} ->
          exports

        {:error, outside} ->
          raise ArgumentError,
                "cannot export #{inspect(outside)} from the boundary #{inspect(module)}: " <>
                  "boundary can only export modules nested under the boundary's own namespace"
      end

    definition = %{
      opts: Keyword.put(opts, :exports, exports),
      pos: %{file: file, line: line},
      app: app(),
      protocol?: Module.defines?(module, {:__impl__, 1}, :def),
      mix_task?: String.starts_with?(inspect(module), "Mix.Tasks.")
    }

    Module.register_attribute(module, Boundary, persist: true, accumulate: false)
    Module.put_attribute(module, Boundary, definition)
    CompilerState.add_module_meta(module, :boundary_def, definition)

    :ok
  end

  @doc """
  The `:check` options AshBoundary declares for a domain, with alias checking on
  by default.

  `boundary`'s own default is `check: [aliases: false]`: a bare module reference
  is unchecked. That default is wrong for Ash. A relationship

      belongs_to :customer, Other.Customer

  names the other domain's resource module and calls no function on it. Under
  `boundary`'s default, a cross-domain relationship into a non-exported resource
  compiles with no warning. AshBoundary exists to make that reference visible,
  so alias checking is on by default here.

  ## Why this reads the project config

  `Boundary.Definition` merges the project-level `boundary: [default: [check: ...]]`
  from `mix.exs` with a boundary's own options in a shallow `Map.merge`, so a
  per-boundary `check:` replaces the whole project-level list. A bare
  `check: [aliases: true]` would silently discard a consuming app's own
  `check: [apps: [...]]` for every AshBoundary domain.

  So this function reads the project-level list and merges into it. An explicit
  `aliases:` entry in it always wins: an app that configures
  `check: [aliases: false]` has made a decision, and AshBoundary honours it.
  """
  @spec check_opts() :: keyword()
  def check_opts, do: check_opts(project_check())

  @doc """
  `check_opts/0` against an explicit project-level `check` keyword list.

      iex> AshBoundary.Declaration.check_opts([])
      [aliases: true]

      iex> AshBoundary.Declaration.check_opts(apps: [:some_app])
      [aliases: true, apps: [:some_app]]

      iex> AshBoundary.Declaration.check_opts(aliases: false)
      [aliases: false]
  """
  @spec check_opts(keyword()) :: keyword()
  def check_opts(project_check) when is_list(project_check),
    do: Keyword.put_new(project_check, :aliases, true)

  @doc """
  Converts fully qualified export modules into the boundary-relative form.

  The boundary module itself is dropped, since `boundary` always exports it.
  Returns `{:error, modules}` listing the modules outside `boundary`'s
  namespace, which `boundary` cannot express as exports.
  """
  @spec relative_exports(module(), [module()]) :: {:ok, [module()]} | {:error, [module()]}
  def relative_exports(boundary, exports) when is_atom(boundary) and is_list(exports) do
    prefix = Module.split(boundary)

    {nested, outside} =
      exports
      |> Enum.uniq()
      |> Enum.reject(&(&1 == boundary))
      |> Enum.split_with(&List.starts_with?(Module.split(&1), prefix))

    case outside do
      [] -> {:ok, Enum.map(nested, &Module.concat(Enum.drop(Module.split(&1), length(prefix))))}
      outside -> {:error, outside}
    end
  end

  @doc """
  Reads back the boundary definition installed on a compiled module.

  Returns `nil` when the module is not a boundary. This is the same persisted
  attribute `Boundary.Definition` reads, so a non-`nil` result means `boundary`
  itself recognises the module.
  """
  @spec definition(module()) :: t() | nil
  def definition(module) when is_atom(module) do
    with true <- Code.ensure_loaded?(module),
         [definition] <- Keyword.get(module.__info__(:attributes), Boundary) do
      definition
    else
      _other -> nil
    end
  end

  @doc "Returns true if `module` has been declared as a boundary."
  @spec declared?(module()) :: boolean()
  def declared?(module) when is_atom(module), do: not is_nil(definition(module))

  defp app, do: Keyword.fetch!(Mix.Project.config(), :app)

  # The same value `Boundary.Definition` uses as the base for every boundary in the
  # project, read the same way, so that merging into it cannot drift from what boundary
  # would otherwise have applied on its own.
  defp project_check do
    Mix.Project.config()
    |> Keyword.get(:boundary, [])
    |> Keyword.get(:default, [])
    |> Keyword.get(:check, [])
  end
end
