defmodule AshBoundary.Info do
  @moduledoc """
  Introspection for domains extended with `AshBoundary`.

  Each function accepts a compiled domain module or the in-progress
  `t:Spark.Dsl.t/0` map a transformer receives.
  """

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
end
