defmodule AshBoundary.Declaration do
  @moduledoc """
  Installs a [`boundary`](https://hex.pm/packages/boundary) declaration onto a module
  that is currently being compiled.

  This is the low-level integration point between AshBoundary and the `boundary`
  library. A Spark transformer computes the `deps` and `exports` lists and calls
  `declare/2`; the module is then indistinguishable, to `boundary`, from one that
  had written `use Boundary, deps: ..., exports: ...` by hand.

  ## Why not just inject `use Boundary`?

  `use Boundary` expands to code that stashes the options in module attributes and
  registers a `@before_compile Boundary.Definition` hook. The hook is what actually
  writes the persisted `Boundary` module attribute that the rest of the library reads.

  Spark runs its transformers from *inside* the DSL module's own `@before_compile`
  hook, and Elixir snapshots the list of `@before_compile` callbacks before invoking
  any of them. A `use Boundary` injected at that point — via
  `Spark.Dsl.Transformer.eval/3` or otherwise — therefore registers a hook that is
  never invoked: the module compiles cleanly and silently ends up with no boundary
  at all. That failure mode is invisible, which makes it worse than a crash.

  So instead of injecting a macro call, this module reproduces the end state of
  `Boundary.Definition.__before_compile__/1` directly, with plain function calls:

    * a persisted `Boundary` module attribute holding the definition map, which is
      what `Boundary.Definition` reads back out of a compiled module, and
    * an entry in `Boundary.Mix.CompilerState`, which is the in-memory cache
      `Mix.Tasks.Compile.Boundary` consults during a compilation run. Skipping this
      is not optional: when the cache exists but has no entry for a module, that
      module is treated as not being a boundary at all.

  Doing the work with function calls rather than injected code has a second benefit.
  Anything injected into the consuming module is seen by boundary's own compiler
  tracer, so an injected `use Boundary` would record spurious cross-boundary
  references from the domain to every module named in it. Calls made from here are
  made by already-compiled AshBoundary code and are invisible to the tracer.

  ## Exports are relative to the boundary root

  `boundary` treats every entry in `exports` as a name *relative to* the boundary
  module: `use Boundary, exports: [Post]` on `MyApp.Blog` exports `MyApp.Blog.Post`.
  Passing the fully qualified `MyApp.Blog.Post` would export
  `MyApp.Blog.MyApp.Blog.Post`, which does not exist and is reported as an
  `unknown_export` error rather than failing loudly.

  `declare/2` therefore takes fully qualified module names and converts them, so
  callers never have to think about it. See `relative_exports/2`.

  The boundary module itself is always exported by `boundary`, so it does not need
  to appear in `exports` and is dropped if passed.

  ## Consuming apps must add the boundary compiler themselves

  Declaring a boundary is not the same as enforcing one. Enforcement lives entirely
  in `Mix.Tasks.Compile.Boundary`, and a Mix compiler can only be enabled by the
  project it runs in — a dependency cannot add itself to a downstream app's
  `:compilers`. So every app using AshBoundary must edit its own `mix.exs`:

      def project do
        [
          compilers: [:boundary] ++ Mix.compilers(),
          # ...
        ]
      end

  Without it, everything still compiles, the declarations are still installed, and
  no violation is ever reported.
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

  Must be called while `module` is still being compiled, which is the case for
  a Spark transformer.

  Supported options:

    * `:exports` - fully qualified modules to export. Converted to the relative
      form `boundary` expects.
    * `:file` / `:line` - source position used in `boundary`'s error messages.
    * every other option is passed through to `boundary` untouched, so `:deps`,
      `:type`, `:check`, `:top_level?` and `:dirty_xrefs` all work as documented
      by `Boundary`.

  Raises `ArgumentError` if an export does not live under the boundary's namespace,
  since `boundary` has no way to express that.
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
  Converts fully qualified export modules into the boundary-relative form.

  The boundary module itself is dropped, since `boundary` always exports it.
  Returns `{:error, modules}` listing any modules that are not nested under
  `boundary`, which `boundary` cannot express as exports.
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
end
