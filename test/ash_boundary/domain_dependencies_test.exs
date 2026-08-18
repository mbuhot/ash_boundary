defmodule AshBoundary.DomainDependenciesTest do
  use ExUnit.Case, async: false

  alias AshBoundary.Clarity.DomainDependencies
  alias AshBoundary.Info
  alias AshBoundary.Test.Compile
  alias AshBoundary.Test.CompileDeps
  alias AshBoundary.Test.Diamond
  alias AshBoundary.Test.Layers
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex

  @layers [
    Layers.Billing,
    Layers.Payroll,
    Layers.Evv,
    Layers.FormBuilder,
    Layers.Insights,
    Layers.Scheduling,
    Layers.Communications,
    Layers.CaseManagement,
    Layers.Authorizations,
    Layers.Platform,
    Layers.Workforce,
    Layers.Notes,
    Layers.Accounts,
    Layers.Audit
  ]

  defp lens, do: %Lens{id: "architect", name: "Architect", icon: fn -> nil end, filter: nil}

  defp domain_vertex(domain), do: %Vertex.Ash.Domain{domain: domain}

  defp app_vertex, do: %Vertex.Application{app: :ash_boundary, description: "", version: "0.1.0"}

  defp render(vertex, theme \\ :light) do
    {:viz, content} = DomainDependencies.render_static(vertex, lens())

    IO.iodata_to_binary(content.(%{theme: theme, zoom_subgraph: nil}))
  end

  defp declared_edges(domains) do
    for domain <- domains, dep <- Info.deps(domain), do: {domain, Info.dep_module(dep)}
  end

  defp drawn_edges(dot) do
    ~r/"([^"]+)" -> "([^"]+)"/
    |> Regex.scan(dot)
    |> Enum.map(fn [_match, from, to] -> {Module.concat([from]), Module.concat([to])} end)
  end

  defp bands(dot) do
    for line <- String.split(dot, "\n"), String.contains?(line, "rank = same") do
      ~r/"AshBoundary\.Test\.Layers\.(\w+)"/
      |> Regex.scan(line)
      |> Enum.map(fn [_match, name] -> name end)
    end
  end

  defp fan_in(edges, target), do: Enum.count(edges, &match?({_from, ^target}, &1))

  defp closure(edges) do
    graph = Enum.group_by(edges, &elem(&1, 0), &elem(&1, 1))

    Map.new(@layers, fn domain ->
      {domain, reachable(graph, Map.get(graph, domain, []), MapSet.new())}
    end)
  end

  defp reachable(_graph, [], seen), do: seen

  defp reachable(graph, [module | queue], seen) do
    if MapSet.member?(seen, module) do
      reachable(graph, queue, seen)
    else
      reachable(graph, Map.get(graph, module, []) ++ queue, MapSet.put(seen, module))
    end
  end

  defp occurrences(dot, needle), do: length(String.split(dot, needle)) - 1

  describe "applies?/2" do
    test "covers domains extended with AshBoundary" do
      assert DomainDependencies.applies?(domain_vertex(AshBoundary.Test.Blog), lens())
      assert DomainDependencies.applies?(domain_vertex(AshBoundary.Test.Dashboard), lens())
    end

    test "skips a domain that is not extended with AshBoundary" do
      modules =
        Compile.modules("""
        defmodule AshBoundary.Test.Plain do
          use Ash.Domain, validate_config_inclusion?: false

          resources do
          end
        end
        """)

      refute DomainDependencies.applies?(domain_vertex(hd(modules)), lens())
    end

    test "skips vertex types other than a domain or an application" do
      vertex = %Vertex.Module{module: AshBoundary.Test.Blog.Post}

      refute DomainDependencies.applies?(vertex, lens())
      refute DomainDependencies.applies?(%Vertex.Root{}, lens())
    end

    test "covers an application once it declares AshBoundary domains" do
      app_vertex = %Vertex.Application{app: :ash_boundary, description: "", version: "0.1.0"}

      refute DomainDependencies.applies?(app_vertex, lens())

      Application.put_env(:ash_boundary, :ash_domains, [AshBoundary.Test.Dashboard])
      on_exit(fn -> Application.delete_env(:ash_boundary, :ash_domains) end)

      assert DomainDependencies.applies?(app_vertex, lens())
    end
  end

  describe "render_static/2 for a domain" do
    test "roots the graph at the domain and highlights it" do
      dot = render(domain_vertex(AshBoundary.Test.Dashboard))

      assert dot =~
               ~s("AshBoundary.Test.Dashboard" [label = "Ash.Domain\\nAshBoundary.Test.Dashboard")

      assert dot =~ ~s(fillcolor = "#FF914D")

      refute dot =~
               ~s("AshBoundary.Test.Blog" [label = "Ash.Domain\\nAshBoundary.Test.Blog", shape = folder, URL = "#ash-domain:ash-boundary-test-blog", style = filled)
    end

    test "draws an edge to each declared dep" do
      dot = render(domain_vertex(AshBoundary.Test.Dashboard))

      assert dot =~ ~s("AshBoundary.Test.Dashboard" -> "AshBoundary.Test.Blog";)
      assert dot =~ ~s("AshBoundary.Test.Dashboard" -> "AshBoundary.Test.Analytics";)
    end

    test "gives every node the URL of its Clarity vertex" do
      dot = render(domain_vertex(AshBoundary.Test.Reports))

      assert dot =~ ~s(URL = "#ash-domain:ash-boundary-test-reports")
      assert dot =~ ~s(URL = "#ash-domain:ash-boundary-test-blog")
    end

    test "follows deps recursively" do
      dot = render(domain_vertex(AshBoundary.Test.Relations))

      assert dot =~ ~s("AshBoundary.Test.Relations" -> "AshBoundary.Test.Blog";)
      assert dot =~ ~s("AshBoundary.Test.Blog" [)
    end

    test "renders a domain with no deps as a single node" do
      dot = render(domain_vertex(AshBoundary.Test.Analytics))

      assert dot =~ ~s("AshBoundary.Test.Analytics" [)
      refute dot =~ "->"
    end

    test "draws a compile-time dep as a dashed labelled edge" do
      dot = render(domain_vertex(AshBoundary.Test.Archive))

      assert dot =~
               ~s("AshBoundary.Test.Archive" -> "AshBoundary.Test.Blog" [style = dashed, label = " compile"];)
    end

    test "renders a dep that is a hand-written boundary as a module vertex" do
      dot = render(domain_vertex(AshBoundary.Test.Ops))

      assert dot =~ ~s(label = "Module\\nAshBoundary.Test.Tooling", shape = box)
      assert dot =~ ~s(URL = "#module:ash-boundary-test-tooling:)
      refute dot =~ ~s(AshBoundary.Test.Tooling" -> )
    end

    test "styles nodes and edges for the dark theme" do
      dot = render(domain_vertex(AshBoundary.Test.Dashboard), :dark)

      assert dot =~ ~s(node [fontname = "system-ui", fontcolor = "#fff")
      assert dot =~ ~s(edge [fontname = "system-ui", fontcolor = "#e5e7eb")
      assert dot =~ ~s(fillcolor = "#ff5757")
    end
  end

  describe "render_static/2 for an application" do
    test "draws every domain of the application and highlights none" do
      Application.put_env(:ash_boundary, :ash_domains, [
        AshBoundary.Test.Dashboard,
        AshBoundary.Test.Archive
      ])

      on_exit(fn -> Application.delete_env(:ash_boundary, :ash_domains) end)

      dot = render(%Vertex.Application{app: :ash_boundary, description: "", version: "0.1.0"})

      assert dot =~ ~s("AshBoundary.Test.Dashboard" -> "AshBoundary.Test.Analytics";)
      assert dot =~ ~s("AshBoundary.Test.Archive" -> "AshBoundary.Test.Blog" [style = dashed)
      refute dot =~ "fillcolor = \"#FF914D\""
    end
  end

  describe "a dependency cycle" do
    setup do
      Compile.modules("""
      defmodule AshBoundary.Test.CycleB do
        use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

        resources do
        end
      end
      """)

      Compile.modules("""
      defmodule AshBoundary.Test.CycleA do
        use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

        boundary do
          deps [AshBoundary.Test.CycleB]
        end

        resources do
        end
      end
      """)

      Compile.modules("""
      defmodule AshBoundary.Test.CycleB do
        use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

        boundary do
          deps [AshBoundary.Test.CycleA]
        end

        resources do
        end
      end
      """)

      :ok
    end

    test "terminates and draws the edge in both directions" do
      dot = render(domain_vertex(AshBoundary.Test.CycleA))

      assert dot =~ ~s("AshBoundary.Test.CycleA" -> "AshBoundary.Test.CycleB";)
      assert dot =~ ~s("AshBoundary.Test.CycleB" -> "AshBoundary.Test.CycleA";)
      assert length(String.split(dot, "[label = ")) == 3
    end

    test "leaves the graph unlayered" do
      refute render(domain_vertex(AshBoundary.Test.CycleA)) =~ "rank = same"
    end
  end

  describe "a dependency cycle with a shared dep" do
    setup do
      Compile.modules("""
      defmodule AshBoundary.Test.FanSink do
        use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

        resources do
        end
      end
      """)

      Compile.modules("""
      defmodule AshBoundary.Test.FanCycleB do
        use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

        boundary do
          deps [AshBoundary.Test.FanSink]
        end

        resources do
        end
      end
      """)

      Compile.modules("""
      defmodule AshBoundary.Test.FanCycleA do
        use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

        boundary do
          deps [AshBoundary.Test.FanCycleB, AshBoundary.Test.FanSink]
        end

        resources do
        end
      end
      """)

      Compile.modules("""
      defmodule AshBoundary.Test.FanCycleB do
        use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

        boundary do
          deps [AshBoundary.Test.FanCycleA, AshBoundary.Test.FanSink]
        end

        resources do
        end
      end
      """)

      %{dot: render(domain_vertex(AshBoundary.Test.FanCycleA))}
    end

    test "keeps every declared edge", %{dot: dot} do
      assert dot =~ ~s("AshBoundary.Test.FanCycleA" -> "AshBoundary.Test.FanCycleB";)
      assert dot =~ ~s("AshBoundary.Test.FanCycleB" -> "AshBoundary.Test.FanCycleA";)
      assert dot =~ ~s("AshBoundary.Test.FanCycleA" -> "AshBoundary.Test.FanSink";)
      assert dot =~ ~s("AshBoundary.Test.FanCycleB" -> "AshBoundary.Test.FanSink";)
    end

    test "leaves the sink reachable", %{dot: dot} do
      assert fan_in(drawn_edges(dot), AshBoundary.Test.FanSink) == 2
    end
  end

  describe "transitive reduction" do
    test "drops the edge across a diamond and keeps its four sides" do
      dot = render(domain_vertex(Diamond.Source))

      assert dot =~ ~s("AshBoundary.Test.Diamond.Source" -> "AshBoundary.Test.Diamond.Left";)
      assert dot =~ ~s("AshBoundary.Test.Diamond.Source" -> "AshBoundary.Test.Diamond.Right";)
      assert dot =~ ~s("AshBoundary.Test.Diamond.Left" -> "AshBoundary.Test.Diamond.Sink";)
      assert dot =~ ~s("AshBoundary.Test.Diamond.Right" -> "AshBoundary.Test.Diamond.Sink";)
      refute dot =~ ~s("AshBoundary.Test.Diamond.Source" -> "AshBoundary.Test.Diamond.Sink")
    end

    test "still draws every node of the diamond" do
      dot = render(domain_vertex(Diamond.Source))

      assert occurrences(dot, "[label = ") == 4
      assert occurrences(dot, "URL = ") == 4
    end

    test "drops a compile-time edge implied by compile-time edges" do
      dot = render(domain_vertex(CompileDeps.CompilePath))

      assert dot =~
               ~s("AshBoundary.Test.CompileDeps.CompilePath" -> ) <>
                 ~s("AshBoundary.Test.CompileDeps.Middle" [style = dashed)

      assert dot =~
               ~s("AshBoundary.Test.CompileDeps.Middle" -> ) <>
                 ~s("AshBoundary.Test.CompileDeps.Base" [style = dashed)

      refute dot =~
               ~s("AshBoundary.Test.CompileDeps.CompilePath" -> ) <>
                 ~s("AshBoundary.Test.CompileDeps.Base")
    end

    test "keeps a compile-time edge implied only by runtime edges" do
      dot = render(domain_vertex(CompileDeps.RuntimePath))

      assert dot =~
               ~s("AshBoundary.Test.CompileDeps.RuntimePath" -> ) <>
                 ~s("AshBoundary.Test.CompileDeps.RuntimeMiddle";)

      assert dot =~
               ~s("AshBoundary.Test.CompileDeps.RuntimePath" -> ) <>
                 ~s("AshBoundary.Test.CompileDeps.Base" [style = dashed, label = " compile"];)
    end

    test "drops a runtime edge implied by compile-time edges" do
      dot = render(domain_vertex(CompileDeps.MixedPath))

      assert dot =~
               ~s("AshBoundary.Test.CompileDeps.MixedPath" -> ) <>
                 ~s("AshBoundary.Test.CompileDeps.Middle" [style = dashed)

      refute dot =~
               ~s("AshBoundary.Test.CompileDeps.MixedPath" -> ) <>
                 ~s("AshBoundary.Test.CompileDeps.Base")
    end
  end

  describe "an application of fourteen layered domains" do
    setup do
      Application.put_env(:ash_boundary, :ash_domains, @layers)
      on_exit(fn -> Application.delete_env(:ash_boundary, :ash_domains) end)

      %{dot: render(app_vertex())}
    end

    test "draws far fewer edges than the domains declare", %{dot: dot} do
      assert length(declared_edges(@layers)) == 36
      assert length(drawn_edges(dot)) == 15
    end

    test "collapses the fan-in to the two sinks", %{dot: dot} do
      declared = declared_edges(@layers)
      drawn = drawn_edges(dot)

      assert fan_in(declared, Layers.Audit) == 10
      assert fan_in(declared, Layers.Accounts) == 8
      assert fan_in(drawn, Layers.Audit) == 1
      assert fan_in(drawn, Layers.Accounts) == 1
    end

    test "keeps the reachability of the declared graph", %{dot: dot} do
      assert closure(drawn_edges(dot)) == closure(declared_edges(@layers))
    end

    test "keeps the edges no path implies", %{dot: dot} do
      drawn = drawn_edges(dot)

      assert {Layers.Billing, Layers.Scheduling} in drawn
      assert {Layers.Scheduling, Layers.CaseManagement} in drawn
      assert {Layers.CaseManagement, Layers.Authorizations} in drawn
      assert {Layers.CaseManagement, Layers.Platform} in drawn
      assert {Layers.Notes, Layers.Accounts} in drawn
      assert {Layers.Accounts, Layers.Audit} in drawn
    end

    test "drops the edges a longer path implies", %{dot: dot} do
      drawn = drawn_edges(dot)

      refute {Layers.Billing, Layers.Accounts} in drawn
      refute {Layers.Billing, Layers.Audit} in drawn
      refute {Layers.Scheduling, Layers.Workforce} in drawn
      refute {Layers.CaseManagement, Layers.Accounts} in drawn
      refute {Layers.Notes, Layers.Audit} in drawn
      refute {Layers.FormBuilder, Layers.Notes} in drawn
    end

    test "bands the domains into ranks by depth from the sinks", %{dot: dot} do
      assert bands(dot) == [
               ["Audit"],
               ["Accounts"],
               ["Notes"],
               ["Platform", "Workforce"],
               ["Authorizations", "Communications"],
               ["CaseManagement", "FormBuilder"],
               ["Insights", "Scheduling"],
               ["Billing", "Evv", "Payroll"]
             ]
    end

    test "gives every node the URL of its Clarity vertex", %{dot: dot} do
      for domain <- @layers do
        assert dot =~ ~s(URL = "##{Vertex.id(domain_vertex(domain))}")
      end

      assert occurrences(dot, "URL = ") == length(@layers)
      assert occurrences(dot, "[label = ") == length(@layers)
    end
  end
end
