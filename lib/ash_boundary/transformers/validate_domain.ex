defmodule AshBoundary.Transformers.ValidateDomain do
  @moduledoc """
  Rejects, at compile time, domains that `boundary` could not correctly
  describe: a hand-written `use Boundary` alongside the extension, a resource or
  an export outside the domain's namespace, an `exports` entry that names a
  resource, a `deps` entry that is not a boundary, and a read-only relationship
  whose target its own domain does not export.
  """

  use Spark.Dsl.Transformer

  alias Ash.Resource.Info, as: ResourceInfo
  alias AshBoundary.Declaration
  alias AshBoundary.Info
  alias Spark.Dsl.Transformer
  alias Spark.Error.DslError

  @doc false
  @spec before?(module()) :: boolean()
  def before?(AshBoundary.Transformers.DeclareBoundary), do: true
  def before?(_), do: false

  @doc false
  @spec after?(module()) :: boolean()
  def after?(AshBoundary.Transformers.DeclareBoundary), do: false
  def after?(_), do: true

  @doc false
  @spec transform(Spark.Dsl.t()) :: {:ok, Spark.Dsl.t()} | {:error, DslError.t()}
  def transform(dsl) do
    module = Transformer.get_persisted(dsl, :module)

    with :ok <- validate_no_manual_declaration(module),
         :ok <- validate_resources_are_nested(dsl, module),
         :ok <- validate_exports_are_nested(dsl, module),
         :ok <- validate_exports_are_not_resources(dsl, module),
         :ok <- validate_deps_are_boundaries(dsl, module),
         :ok <- validate_read_only_targets_are_not_written(dsl, module) do
      defer_read_only_target_check(dsl, module)
      {:ok, dsl}
    end
  end

  @doc false
  @spec __after_compile__(Macro.Env.t(), binary()) :: :ok
  def __after_compile__(%{module: module}, _bytecode) do
    problems =
      for relationship <- Info.read_only_relationships(module),
          domain = owning_domain(relationship),
          relationship.destination not in Info.exports(domain),
          do: {relationship, domain}

    case problems do
      [] -> :ok
      problems -> raise read_only_targets_error(module, problems)
    end
  end

  defp validate_no_manual_declaration(module) do
    if manual_declaration?(module) do
      {:error,
       DslError.exception(
         module: module,
         path: [:boundary],
         message: """
         #{inspect(module)} calls `use Boundary` as well as being extended with `AshBoundary`.

         Both install the boundary declaration from a `@before_compile` hook, and whichever \
         runs last overwrites the other. Which declaration #{inspect(module)} ends up with \
         would therefore depend on the order the two `use` calls happen to appear in, so \
         this is rejected rather than left to chance.

         `AshBoundary` manages the declaration for you: `deps` come from the `boundary` \
         section, and `exports` are computed from the domain-level `define` calls in \
         `resources`. Remove the `use Boundary` line.

         If you need something `AshBoundary` does not express, do the opposite instead: \
         drop `AshBoundary` from `extensions` and hand-write the full `use Boundary` \
         declaration.\
         """
       )}
    else
      :ok
    end
  end

  defp manual_declaration?(module) do
    Module.open?(module) and
      module
      |> Module.get_attribute(:before_compile, [])
      |> List.wrap()
      |> Enum.any?(&(hook_module(&1) == Boundary.Definition))
  end

  defp hook_module({module, _function}), do: module
  defp hook_module(module), do: module

  defp validate_resources_are_nested(dsl, module) do
    prefix = Module.split(module)

    case Enum.reject(Info.resources(dsl), &nested?(&1, prefix)) do
      [] -> :ok
      outside -> {:error, not_nested_error(module, outside)}
    end
  end

  defp nested?(resource, prefix), do: List.starts_with?(Module.split(resource), prefix)

  defp not_nested_error(module, outside) do
    DslError.exception(
      module: module,
      path: [:resources],
      message: """
      #{resource_list(outside)} not nested under #{inspect(module)}.

      `boundary` assigns a module to a boundary purely by module-name nesting: everything \
      called #{inspect(module)}.* belongs to the #{inspect(module)} boundary, and nothing \
      else can. So #{pronoun(outside)} could never be exported by this domain, and would \
      not be protected by it either - outside code could reach #{pronoun(outside)} freely \
      while the rest of #{inspect(module)} was enforced.

      Fix this by renaming #{pronoun(outside)} to sit under #{inspect(module)}, for \
      example #{inspect(suggested_name(module, hd(outside)))}, and updating any references.

      If the resource genuinely belongs to another domain, reference it from that domain \
      instead. If neither is possible, remove `AshBoundary` from #{inspect(module)}'s \
      extensions: this domain cannot be given a boundary as it stands.\
      """
    )
  end

  defp resource_list([resource]), do: "The resource #{inspect(resource)} is"

  defp resource_list(resources) do
    "The resources #{Enum.map_join(resources, ", ", &inspect/1)} are"
  end

  defp pronoun([_resource]), do: "it"
  defp pronoun(_resources), do: "they"

  defp suggested_name(module, resource) do
    Module.concat(module, List.last(Module.split(resource)))
  end

  defp validate_exports_are_nested(dsl, module) do
    prefix = Module.split(module)

    case Enum.reject(Info.declared_exports(dsl), &nested?(&1, prefix)) do
      [] -> :ok
      outside -> {:error, exports_not_nested_error(module, outside)}
    end
  end

  defp exports_not_nested_error(module, outside) do
    DslError.exception(
      module: module,
      path: [:boundary, :exports],
      message: """
      #{module_list(outside)} not nested under #{inspect(module)}.

      `boundary` assigns a module to a boundary purely by module-name nesting, so \
      #{inspect(module)} can only export modules called #{inspect(module)}.*.

      Rename #{pronoun(outside)} to sit under #{inspect(module)}, or export \
      #{pronoun(outside)} from the boundary that owns #{pronoun(outside)} and name that \
      boundary in this domain's `deps`.\
      """
    )
  end

  defp validate_exports_are_not_resources(dsl, module) do
    resources = MapSet.new(Info.resources(dsl))

    case Enum.filter(Info.declared_exports(dsl), &MapSet.member?(resources, &1)) do
      [] -> :ok
      listed -> {:error, resource_exports_error(module, listed)}
    end
  end

  defp resource_exports_error(module, listed) do
    DslError.exception(
      module: module,
      path: [:boundary, :exports],
      message: """
      #{module_list(listed)} listed in `exports`, and also #{resource_of(listed)} \
      #{inspect(module)}.

      Whether a resource is exported comes from `resources`: one with at least one \
      domain-level `define` is public, and one without stays internal. `exports` is for \
      public modules that are not resources.

      Add a `define` to #{inspect(hd(listed))} under `resources` instead, and remove \
      #{pronoun(listed)} from `exports`.\
      """
    )
  end

  defp module_list([module]), do: "The module #{inspect(module)} is"

  defp module_list(modules) do
    "The modules #{Enum.map_join(modules, ", ", &inspect/1)} are"
  end

  defp resource_of([_module]), do: "a resource of"
  defp resource_of(_modules), do: "resources of"

  defp validate_deps_are_boundaries(dsl, module) do
    problems =
      for dep <- Enum.uniq(Info.dep_modules(dsl)),
          problem = dep_problem(module, dep),
          do: {dep, problem}

    case problems do
      [] -> :ok
      problems -> {:error, deps_error(module, problems)}
    end
  end

  defp dep_problem(module, module), do: :self

  defp dep_problem(_module, dep) do
    case Code.ensure_compiled(dep) do
      {:module, _module} -> if not Declaration.declared?(dep), do: :not_a_boundary
      {:error, :unavailable} -> :cycle
      {:error, reason} -> {:missing, reason}
    end
  end

  defp deps_error(module, problems) do
    DslError.exception(
      module: module,
      path: [:boundary, :deps],
      message:
        Enum.map_join(problems, "\n\n", fn {dep, problem} -> explain(module, dep, problem) end)
    )
  end

  defp explain(module, _dep, :self) do
    """
    #{inspect(module)} lists itself in `deps`.

    A boundary may always reach its own modules, so this entry has no effect. Remove it.\
    """
  end

  defp explain(module, dep, :not_a_boundary) do
    """
    #{inspect(module)} declares a dependency on #{inspect(dep)}, which is not a boundary.

    Every entry in `deps` has to declare a boundary of its own, otherwise there is \
    nothing for the dependency to be checked against - `boundary` cannot tell which \
    modules #{inspect(dep)} owns, or which of them it considers public.

    If #{inspect(dep)} is an `Ash.Domain`, add `extensions: [AshBoundary]` to it. If it \
    is an ordinary module you want to treat as a boundary, add `use Boundary` to it. \
    Otherwise remove it from `deps`: only boundaries need to be declared, and plain \
    modules in your own app are not boundaries.\
    """
  end

  defp explain(module, dep, :cycle) do
    """
    #{inspect(module)} and #{inspect(dep)} depend on each other.

    #{inspect(dep)} exists, but is still being compiled and is itself waiting on \
    #{inspect(module)}, so neither can be checked against the other. AshBoundary has to \
    know whether a dep is a boundary while the domain declaring it compiles, which a \
    cycle makes impossible.

    `boundary` rejects mutually dependent boundaries anyway: a dependency is meant to \
    record which side is allowed to know about the other, and two domains that both \
    reach into each other have no boundary between them worth enforcing. Break the cycle \
    by removing one of the two `deps` entries, and move whatever the removed direction \
    needed behind a code interface on the side that keeps its dep.\
    """
  end

  defp explain(module, dep, {:missing, reason}) do
    """
    #{inspect(module)} declares a dependency on #{inspect(dep)}, which could not be \
    loaded (#{inspect(reason)}).

    `deps` entries are module names; check this one for a typo, and that the module it \
    names is compiled as part of this application or one of its dependencies.\
    """
  end

  defp validate_read_only_targets_are_not_written(dsl, module) do
    case written_read_only_targets(dsl) do
      [] -> :ok
      conflicts -> {:error, written_targets_error(module, conflicts)}
    end
  end

  defp written_read_only_targets(dsl) do
    if Info.allow_read_only_relationships?(dsl) do
      {read_only, written} =
        dsl
        |> Info.cross_boundary_relationships()
        |> Enum.split_with(&Info.read_only_relationship?/1)

      for relationship <- read_only,
          writer <- written,
          writer.destination == relationship.destination,
          do: {relationship, writer}
    else
      []
    end
  end

  defp written_targets_error(module, conflicts) do
    DslError.exception(
      module: module,
      path: [:boundary, :allow_read_only_relationships?],
      message:
        Enum.map_join(conflicts, "\n\n", fn {relationship, writer} ->
          explain_written_target(relationship, writer)
        end)
    )
  end

  defp explain_written_target(relationship, writer) do
    """
    #{inspect(relationship.destination)} is the destination of the read-only relationship \
    `:#{relationship.name}` on #{inspect(relationship.source)}, and of the writable \
    #{writer.type} `:#{writer.name}` on #{inspect(writer.source)}.

    `allow_read_only_relationships? true` exempts a target module rather than a single \
    relationship, so the exemption would cover #{inspect(writer.source)}.#{writer.name} as \
    well.

    Name the domain that owns #{inspect(relationship.destination)} in this domain's `deps`, \
    which is what #{inspect(writer.source)}.#{writer.name} needs in any case.\
    """
  end

  defp defer_read_only_target_check(dsl, module) do
    if Info.allow_read_only_relationships?(dsl) do
      Module.put_attribute(module, :after_compile, {__MODULE__, :__after_compile__})
    end

    :ok
  end

  defp owning_domain(relationship) do
    with {:module, _module} <- Code.ensure_compiled(relationship.destination),
         domain when not is_nil(domain) <- declared_domain(relationship),
         {:module, _module} <- Code.ensure_compiled(domain),
         true <- Spark.Dsl.is?(domain, Ash.Domain) do
      domain
    else
      _other -> nil
    end
  end

  defp declared_domain(relationship) do
    relationship.domain || ResourceInfo.domain(relationship.destination)
  end

  defp read_only_targets_error(module, problems) do
    DslError.exception(
      module: module,
      path: [:boundary, :allow_read_only_relationships?],
      message:
        Enum.map_join(problems, "\n\n", fn {relationship, domain} ->
          explain_target(module, relationship, domain)
        end)
    )
  end

  defp explain_target(module, relationship, domain) do
    """
    #{inspect(relationship.destination)} is the destination of the read-only relationship \
    `:#{relationship.name}` on #{inspect(relationship.source)}, and is not exported by \
    #{inspect(domain)}.

    `allow_read_only_relationships? true` waives the `deps` entry for a read-only \
    relationship. It does not waive the target's own export: \
    #{inspect(relationship.destination)} has no domain-level `define` in \
    #{inspect(domain)}, so it stays internal to that domain and #{inspect(module)} may not \
    name it.

    Add a `define` for #{inspect(relationship.destination)} to the `resources` block of \
    #{inspect(domain)}, or remove the relationship.\
    """
  end
end
