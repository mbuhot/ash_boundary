defmodule AshBoundary.DomainDependenciesTest do
  use ExUnit.Case, async: false

  alias AshBoundary.Clarity.DomainDependencies
  alias AshBoundary.Test.Compile
  alias Clarity.Perspective.Lens
  alias Clarity.Vertex

  defp lens, do: %Lens{id: "architect", name: "Architect", icon: fn -> nil end, filter: nil}

  defp domain_vertex(domain), do: %Vertex.Ash.Domain{domain: domain}

  defp render(vertex, theme \\ :light) do
    {:viz, content} = DomainDependencies.render_static(vertex, lens())

    IO.iodata_to_binary(content.(%{theme: theme, zoom_subgraph: nil}))
  end

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
  end
end
