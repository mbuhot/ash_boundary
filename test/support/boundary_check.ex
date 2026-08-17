defmodule AshBoundary.Test.BoundaryCheck do
  @moduledoc """
  Runs `boundary`'s real checker over fixture modules, without needing a failing
  `mix compile`.

  `Mix.Tasks.Compile.Boundary` is only a thin shell over two public pieces:
  a `Boundary.view()` describing which modules belong to which boundary, and a
  list of `t:Boundary.ref/0` cross-module references gathered by its compiler
  tracer. `Boundary.errors/2` combines them. This module assembles both.

  References are captured by installing boundary's own tracer and compiling a
  string, rather than being hand-written, so the reference shape under test is
  the one the real compiler produces.
  """

  # Aliased rather than referenced directly: the plain alias `Boundary` would
  # shadow the `Boundary` module this whole helper is built on.
  alias Boundary.Mix.Classifier
  alias Boundary.Mix.CompilerState
  alias Mix.Tasks.Compile.Boundary, as: BoundaryCompiler

  @doc """
  Compiles `source` with boundary's compiler tracer installed and returns the
  references recorded for `module`.
  """
  @spec capture_references(module(), String.t()) :: [map()]
  def capture_references(module, source) do
    {:ok, pid} = CompilerState.start_link(force: true)
    Process.unlink(pid)

    previous_tracers = Code.get_compiler_option(:tracers) || []
    Code.put_compiler_option(:tracers, [BoundaryCompiler | previous_tracers])

    # A fixture that defines a struct — any Ash resource does — brings a `defimpl Inspect`
    # with it, and protocols were already consolidated when the test suite was compiled.
    # The resulting warning says nothing about the code under test.
    previously_ignored = Code.get_compiler_option(:ignore_already_consolidated) || false
    Code.put_compiler_option(:ignore_already_consolidated, true)

    try do
      Code.compile_string(source, "#{Macro.underscore(module)}.ex")
    after
      Code.put_compiler_option(:tracers, previous_tracers)
      Code.put_compiler_option(:ignore_already_consolidated, previously_ignored)
    end

    # The tracer's reference table is shared and never cleared between captures,
    # so select by originating module rather than reaching for its private name.
    CompilerState.references()
    |> Enum.filter(&(&1.from == module))
    |> Enum.sort_by(&{&1.line, &1.type})
  end

  @doc """
  Returns every `boundary` error raised by `references`, given a world made up
  only of `modules`.
  """
  @spec errors([module()], [map()]) :: [tuple()]
  def errors(modules, references), do: Boundary.errors(view(modules), references)

  @doc """
  Returns only the cross-boundary reference errors, as `{type, from, to}` triples.
  """
  @spec reference_errors([module()], [map()]) :: [{atom(), module(), module()}]
  def reference_errors(modules, references) do
    for {:invalid_reference, error} <- errors(modules, references),
        do: {error.type, error.reference.from, error.reference.to}
  end

  @doc """
  Builds a `Boundary.view()` in which `modules` are the only modules in the world.
  """
  @spec view([module()]) :: map()
  def view(modules) do
    app = Keyword.fetch!(Mix.Project.config(), :app)

    definitions =
      for module <- modules,
          definition = AshBoundary.Declaration.definition(module),
          into: %{},
          do: {module, definition}

    boundaries =
      for {module, _} <- definitions,
          boundary = Boundary.Definition.get(module, definitions),
          do: Map.merge(boundary, %{name: module, implicit?: false, modules: []})

    classifier =
      Classifier.classify(Classifier.new(), app, modules, boundaries)

    unclassified =
      modules
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(Map.keys(classifier.modules)))

    %{
      version: to_string(Application.spec(:boundary, :vsn) || "unknown"),
      main_app: app,
      classifier: classifier,
      unclassified_modules: unclassified,
      module_to_app: Map.new(modules, &{&1, app}),
      external_deps: MapSet.new(),
      boundary_defs: definitions,
      protocol_impls: MapSet.new()
    }
  end
end
