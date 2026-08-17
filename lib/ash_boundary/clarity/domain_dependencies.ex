with {:module, Clarity.Content} <- Code.ensure_loaded(Clarity.Content) do
  defmodule AshBoundary.Clarity.DomainDependencies do
    @moduledoc "Clarity content provider rendering a domain's `deps` as a navigable graph."

    @behaviour Clarity.Content

    alias AshBoundary.Info
    alias Clarity.Vertex

    @highlight %{light: "#FF914D", dark: "#ff5757"}

    @impl Clarity.Content
    def name, do: "Boundary Dependencies"

    @impl Clarity.Content
    def description, do: "Domains reachable through the boundary's declared deps"

    @impl Clarity.Content
    def sort_priority, do: 10

    @impl Clarity.Content
    def applies?(%Vertex.Ash.Domain{domain: domain}, _lens), do: domain?(domain)
    def applies?(%Vertex.Application{app: app}, _lens), do: domains(app) != []
    def applies?(_vertex, _lens), do: false

    @impl Clarity.Content
    def render_static(%Vertex.Ash.Domain{domain: domain}, _lens) do
      {:viz, fn props -> dot([domain], [domain], props) end}
    end

    def render_static(%Vertex.Application{app: app}, _lens) do
      {:viz, fn props -> dot(domains(app), [], props) end}
    end

    @spec dot([module()], [module()], Clarity.Content.static_content_props()) :: iodata()
    defp dot(roots, highlight, %{theme: theme}) do
      {modules, edges} = walk(roots, %{}, [])

      [
        "digraph {\n",
        "  bgcolor = transparent;\n",
        "  rankdir = LR;\n",
        "  node [fontname = \"system-ui\"",
        node_theme(theme),
        "];\n",
        "  edge [fontname = \"system-ui\"",
        edge_theme(theme),
        "];\n",
        Enum.map(modules, &node_statement(&1, highlight, theme)),
        Enum.map(edges, &edge_statement/1),
        "}\n"
      ]
    end

    @spec walk([module()], %{optional(module()) => true}, [
            {module(), module(), :compile | :runtime}
          ]) :: {[module()], [{module(), module(), :compile | :runtime}]}
    defp walk([], seen, edges), do: {seen |> Map.keys() |> Enum.sort(), Enum.reverse(edges)}

    defp walk([module | queue], seen, edges) do
      if Map.has_key?(seen, module) do
        walk(queue, seen, edges)
      else
        deps = if domain?(module), do: Info.deps(module), else: []

        walk(
          Enum.map(deps, &Info.dep_module/1) ++ queue,
          Map.put(seen, module, true),
          Enum.reduce(deps, edges, &[{module, Info.dep_module(&1), dep_type(&1)} | &2])
        )
      end
    end

    @spec node_statement(module(), [module()], Clarity.Content.theme()) :: iodata()
    defp node_statement(module, highlight, theme) do
      vertex = vertex(module)

      [
        "  ",
        dot_id(module),
        " [label = ",
        quoted([Vertex.type_label(vertex), "\\n", Vertex.name(vertex)]),
        ", shape = ",
        Vertex.GraphShapeProvider.shape(vertex),
        ", URL = ",
        quoted(["#", Vertex.id(vertex)]),
        if module in highlight do
          color = Map.fetch!(@highlight, theme)
          [", style = filled, fillcolor = \"", color, "\", color = \"", color, "\""]
        else
          []
        end,
        "];\n"
      ]
    end

    @spec edge_statement({module(), module(), :compile | :runtime}) :: iodata()
    defp edge_statement({from, to, :compile}) do
      ["  ", dot_id(from), " -> ", dot_id(to), " [style = dashed, label = \" compile\"];\n"]
    end

    defp edge_statement({from, to, :runtime}) do
      ["  ", dot_id(from), " -> ", dot_id(to), ";\n"]
    end

    @spec vertex(module()) :: Vertex.t()
    defp vertex(module) do
      if domain?(module) do
        %Vertex.Ash.Domain{domain: module}
      else
        %Vertex.Module{module: module, version: module_version(module)}
      end
    end

    @spec module_version(module()) :: :unknown | integer()
    defp module_version(module) do
      with true <- Code.ensure_loaded?(module),
           [version] <- module.module_info(:attributes)[:vsn] do
        version
      else
        _other -> :unknown
      end
    end

    @spec domain?(module()) :: boolean()
    defp domain?(module) do
      Code.ensure_loaded?(module) and function_exported?(module, :spark_dsl_config, 0) and
        AshBoundary in Spark.extensions(module)
    end

    @spec domains(Application.app()) :: [module()]
    defp domains(app), do: app |> Ash.Info.domains() |> Enum.filter(&domain?/1)

    @spec dep_type(Info.dep()) :: :compile | :runtime
    defp dep_type({_module, :compile}), do: :compile
    defp dep_type(_dep), do: :runtime

    @spec dot_id(module()) :: iodata()
    defp dot_id(module), do: quoted(inspect(module))

    @spec quoted(iodata()) :: iodata()
    defp quoted(content), do: [?", content, ?"]

    @spec node_theme(Clarity.Content.theme()) :: iodata()
    defp node_theme(:dark),
      do: ", fontcolor = \"#fff\", style = filled, fillcolor = \"#374151\", color = \"#9ca3af\""

    defp node_theme(:light), do: []

    @spec edge_theme(Clarity.Content.theme()) :: iodata()
    defp edge_theme(:dark), do: ", fontcolor = \"#e5e7eb\", color = \"#d1d5db\""
    defp edge_theme(:light), do: []
  end
end
