defmodule AshBoundary.Info do
  @moduledoc """
  Introspection for domains extended with `AshBoundary`.

  Each function accepts a compiled domain module or the in-progress
  `t:Spark.Dsl.t/0` map a transformer receives.
  """

  alias Ash.Resource.Info, as: ResourceInfo
  alias Spark.Dsl.Extension

  @typedoc "A `deps` entry, in one of the two forms the DSL accepts."
  @type dep :: module() | {module(), :compile | :runtime}

  @typedoc "A domain module, or the DSL state of one still being compiled."
  @type domain :: Spark.Dsl.t() | Ash.Domain.t()

  @doc """
  The `deps` declared in the `boundary` section, exactly as written.

  Returns `[]` for a domain with no `boundary` section.
  """
  @spec deps(domain()) :: [dep()]
  def deps(domain), do: Extension.get_opt(domain, [:boundary], :deps, [])

  @doc """
  The modules named by `deps/1`, with any `{module, type}` pairs unwrapped.
  """
  @spec dep_modules(domain()) :: [module()]
  def dep_modules(domain), do: Enum.map(deps(domain), &dep_module/1)

  @doc """
  The module named by a single `deps` entry.

  ## Examples

      iex> AshBoundary.Info.dep_module(MyApp.Accounts)
      MyApp.Accounts

      iex> AshBoundary.Info.dep_module({MyApp.Accounts, :compile})
      MyApp.Accounts
  """
  @spec dep_module(dep()) :: module()
  def dep_module({module, _type}) when is_atom(module), do: module
  def dep_module(module) when is_atom(module), do: module

  @doc """
  The `exports` declared in the `boundary` section, exactly as written.

  Returns `[]` for a domain with no `boundary` section.
  """
  @spec declared_exports(domain()) :: [module()]
  def declared_exports(domain), do: Extension.get_opt(domain, [:boundary], :exports, [])

  @doc """
  Every resource the domain references, exported and internal.
  """
  @spec resources(domain()) :: [module()]
  def resources(domain), do: Enum.map(resource_references(domain), & &1.resource)

  @doc """
  Whether a read-only relationship may cross into another domain without a
  `deps` entry.
  """
  @spec allow_read_only_relationships?(domain()) :: boolean()
  def allow_read_only_relationships?(domain),
    do: Extension.get_opt(domain, [:boundary], :allow_read_only_relationships?, false)

  @doc """
  The relationships this domain's resources declare on a resource outside the
  domain's namespace.

  A resource that is not compiled yet contributes nothing.
  """
  @spec cross_boundary_relationships(domain()) :: [Ash.Resource.Relationships.relationship()]
  def cross_boundary_relationships(domain) do
    prefix = Module.split(module(domain))

    for resource <- resources(domain),
        relationship <- relationships(resource),
        not List.starts_with?(Module.split(relationship.destination), prefix),
        do: relationship
  end

  @doc """
  Whether a relationship is read-only, meaning it declares `writable?: false`.

  A `many_to_many` has no `writable?` of its own and is never read-only.
  """
  @spec read_only_relationship?(Ash.Resource.Relationships.relationship()) :: boolean()
  def read_only_relationship?(relationship), do: Map.get(relationship, :writable?) == false

  @doc """
  The relationships `cross_boundary_relationships/1` returns that are read-only.

  Returns `[]` unless `allow_read_only_relationships?/1` is set.
  """
  @spec read_only_relationships(domain()) :: [Ash.Resource.Relationships.relationship()]
  def read_only_relationships(domain) do
    if allow_read_only_relationships?(domain) do
      Enum.filter(cross_boundary_relationships(domain), &read_only_relationship?/1)
    else
      []
    end
  end

  @doc "The resources named by `read_only_relationships/1`, each listed once."
  @spec read_only_relationship_targets(domain()) :: [module()]
  def read_only_relationship_targets(domain) do
    domain
    |> read_only_relationships()
    |> Enum.map(& &1.destination)
    |> Enum.uniq()
  end

  @doc """
  Every module `read_only_relationships/1` sanctions a reference to, each
  listed once: the targets of `read_only_relationship_targets/1`, plus the
  modules each relationship's `manual` option names - the implementation
  module itself, and any module given as one of its option values.

  Returns `[]` unless `allow_read_only_relationships?/1` is set.
  """
  @spec read_only_reference_modules(domain()) :: [module()]
  def read_only_reference_modules(domain) do
    relationships = read_only_relationships(domain)

    targets = Enum.map(relationships, & &1.destination)
    manual = Enum.flat_map(relationships, &manual_modules/1)

    Enum.uniq(targets ++ manual)
  end

  defp manual_modules(relationship) do
    case Map.get(relationship, :manual) do
      nil -> []
      {module, opts} when is_atom(module) -> [module | manual_opt_modules(opts)]
      module when is_atom(module) -> [module]
    end
  end

  defp manual_opt_modules(opts) when is_list(opts) do
    for {_key, value} <- opts, elixir_module?(value), do: value
  end

  defp manual_opt_modules(_opts), do: []

  defp elixir_module?(value) do
    is_atom(value) and String.starts_with?(Atom.to_string(value), "Elixir.")
  end

  @doc """
  The modules this domain exports: the domain module, each resource with at
  least one domain-level `define`, and the modules named by `declared_exports/1`.

  The domain module leads the list. `boundary` exports a boundary's root module
  implicitly, so `AshBoundary.Declaration` drops it when it installs the
  declaration. See `AshBoundary.Declaration.relative_exports/2`.
  """
  @spec exports(domain()) :: [module()]
  def exports(domain) do
    defined =
      domain
      |> resource_references()
      |> Enum.filter(&(&1.definitions != []))
      |> Enum.map(& &1.resource)

    Enum.uniq([module(domain) | defined] ++ declared_exports(domain))
  end

  @doc """
  The domain module, from the module itself or from its DSL state.
  """
  @spec module(domain()) :: module()
  def module(domain) when is_atom(domain), do: domain
  def module(domain), do: Extension.get_persisted(domain, :module)

  defp resource_references(domain), do: Extension.get_entities(domain, [:resources])

  defp relationships(resource) do
    case Code.ensure_compiled(resource) do
      {:module, _module} -> ResourceInfo.relationships(resource)
      {:error, _reason} -> []
    end
  end
end
