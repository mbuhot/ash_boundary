with {:module, Clarity.Content} <- Code.ensure_loaded(Clarity.Content) do
  defmodule AshBoundary.Clarity.DomainDependencies do
    @moduledoc "Clarity content provider rendering a domain's `deps` as a navigable graph."

    @behaviour Clarity.Content

    alias AshBoundary.Info
    alias Clarity.Vertex

    @highlight %{light: "#FF914D", dark: "#ff5757"}

    @typep edge :: {module(), module(), :compile | :runtime}
    @typep adjacency :: %{optional(module()) => [module()]}
    @typep seen :: %{optional(module()) => true}
    @typep depths :: %{optional(module()) => non_neg_integer()}

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
      {edges, layers} = layout(modules, edges)

      [
        "digraph {\n",
        "  bgcolor = transparent;\n",
        "  rankdir = TB;\n",
        "  node [fontname = \"system-ui\"",
        node_theme(theme),
        "];\n",
        "  edge [fontname = \"system-ui\"",
        edge_theme(theme),
        "];\n",
        Enum.map(modules, &node_statement(&1, highlight, theme)),
        Enum.map(layers, &rank_statement/1),
        Enum.map(edges, &edge_statement/1),
        "}\n"
      ]
    end

    @spec walk([module()], seen(), [edge()]) :: {[module()], [edge()]}
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

    @spec layout([module()], [edge()]) :: {[edge()], [[module()]]}
    defp layout(modules, edges) do
      graph = adjacency(edges)

      if cyclic?(modules, graph) do
        {edges, []}
      else
        reduced = reduce(edges, graph)
        {reduced, layers(modules, adjacency(reduced))}
      end
    end

    @spec reduce([edge()], adjacency()) :: [edge()]
    defp reduce(edges, graph) do
      compile_graph = edges |> Enum.filter(&match?({_from, _to, :compile}, &1)) |> adjacency()

      Enum.reject(edges, fn
        {from, to, :compile} -> implied?(compile_graph, from, to)
        {from, to, :runtime} -> implied?(graph, from, to)
      end)
    end

    @spec implied?(adjacency(), module(), module()) :: boolean()
    defp implied?(graph, from, to) do
      graph
      |> Map.get(from, [])
      |> Enum.any?(&(&1 != to and reachable?(graph, [&1], %{}, to)))
    end

    @spec cyclic?([module()], adjacency()) :: boolean()
    defp cyclic?(modules, graph) do
      Enum.any?(modules, &reachable?(graph, Map.get(graph, &1, []), %{}, &1))
    end

    @spec reachable?(adjacency(), [module()], seen(), module()) :: boolean()
    defp reachable?(_graph, [], _seen, _target), do: false

    defp reachable?(graph, [module | queue], seen, target) do
      cond do
        module == target ->
          true

        Map.has_key?(seen, module) ->
          reachable?(graph, queue, seen, target)

        true ->
          reachable?(
            graph,
            Map.get(graph, module, []) ++ queue,
            Map.put(seen, module, true),
            target
          )
      end
    end

    @spec layers([module()], adjacency()) :: [[module()]]
    defp layers(modules, graph) do
      depths = Enum.reduce(modules, %{}, &depth(&1, graph, &2))

      modules
      |> Enum.group_by(&Map.fetch!(depths, &1))
      |> Enum.sort()
      |> Enum.map(fn {_depth, layer} -> layer end)
    end

    @spec depth(module(), adjacency(), depths()) :: depths()
    defp depth(module, graph, depths) do
      if Map.has_key?(depths, module) do
        depths
      else
        deps = Map.get(graph, module, [])
        depths = Enum.reduce(deps, depths, &depth(&1, graph, &2))

        Map.put(depths, module, 1 + Enum.reduce(deps, -1, &max(&2, Map.fetch!(depths, &1))))
      end
    end

    @spec adjacency([edge()]) :: adjacency()
    defp adjacency(edges) do
      Enum.group_by(edges, fn {from, _to, _type} -> from end, fn {_from, to, _type} -> to end)
    end

    @spec rank_statement([module()]) :: iodata()
    defp rank_statement(modules) do
      ["  { rank = same; ", Enum.map(modules, &[dot_id(&1), "; "]), "}\n"]
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

    @spec edge_statement(edge()) :: iodata()
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
