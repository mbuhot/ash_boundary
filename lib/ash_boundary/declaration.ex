defmodule AshBoundary.Declaration do
  @moduledoc """
  Installs a `boundary` declaration onto a module that is currently being
  compiled.
  """

  alias Boundary.Mix.CompilerState

  @typedoc "The definition map `boundary` stores in the persisted attribute."
  @type t :: %{
          opts: keyword(),
          pos: %{file: String.t() | nil, line: pos_integer() | nil},
          app: atom(),
          protocol?: boolean(),
          mix_task?: boolean()
        }

  @doc """
  Declares `module` as a boundary, as if it had called `use Boundary`. Must be
  called while `module` is still being compiled.

    * `:exports` - fully qualified modules, converted to the relative form
      `boundary` expects.
    * `:file` / `:line` - source position for `boundary`'s error messages.
    * Any other option passes through to `boundary` untouched.

  Applies no defaults. Raises `ArgumentError` if an export lives outside the
  boundary's namespace.
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

  Drops the boundary module itself. Returns `{:error, modules}` for modules
  outside `boundary`'s namespace.
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
  Reads back the boundary definition installed on a compiled module, or `nil`.
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
