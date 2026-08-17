defmodule AshBoundary.DeclarationTest do
  use ExUnit.Case, async: true

  alias AshBoundary.Declaration
  alias AshBoundary.Test.Blog

  doctest AshBoundary.Declaration

  describe "declaring a boundary from a Spark transformer" do
    test "the domain module really is a boundary as far as `boundary` is concerned" do
      # `Boundary.Definition.get/2` with no definition cache is the path `boundary`
      # takes for an already-compiled module: it reads the persisted attribute off
      # the beam. A non-nil result here means nothing about AshBoundary is involved
      # in the answer.
      assert definition = Boundary.Definition.get(Blog, nil)
      assert definition.app == :ash_boundary
      assert definition.check.in
      assert definition.check.out
      assert definition.errors == []
    end

    test "exports are the resources with a domain-level define, expanded absolutely" do
      definition = Boundary.Definition.get(Blog, nil)

      assert definition.exports == [Blog.Post]
      refute Blog.Comment in definition.exports
    end

    test "the boundary root is not listed, because `boundary` exports it implicitly" do
      refute Blog in Boundary.Definition.get(Blog, nil).exports
    end

    test "declared deps survive the round trip" do
      assert Boundary.Definition.get(AshBoundary.Test.Reports, nil).deps ==
               [{Blog, :runtime}]
    end

    test "the raw attribute matches the shape `use Boundary` would have produced" do
      assert %{
               opts: opts,
               pos: %{file: file, line: 1},
               app: :ash_boundary,
               protocol?: false,
               mix_task?: false
             } = Declaration.definition(Blog)

      assert String.ends_with?(file, "test/support/blog.ex")
      # Stored relative to the boundary root, which is what `boundary` expects.
      assert Keyword.fetch!(opts, :exports) == [Post]
    end

    test "declared?/1 distinguishes boundaries from ordinary modules" do
      assert Declaration.declared?(Blog)
      refute Declaration.declared?(Blog.Post)
      refute Declaration.declared?(Enum)
    end
  end

  describe "relative_exports/2" do
    test "strips the boundary's own namespace" do
      assert Declaration.relative_exports(MyApp.Blog, [MyApp.Blog.Post, MyApp.Blog.Nested.Tag]) ==
               {:ok, [Post, Nested.Tag]}
    end

    test "drops the boundary module itself and duplicates" do
      assert Declaration.relative_exports(MyApp.Blog, [
               MyApp.Blog,
               MyApp.Blog.Post,
               MyApp.Blog.Post
             ]) ==
               {:ok, [Post]}
    end

    test "reports modules that boundary cannot express as exports" do
      assert Declaration.relative_exports(MyApp.Blog, [MyApp.Blog.Post, MyApp.Other.Thing]) ==
               {:error, [MyApp.Other.Thing]}
    end
  end

  describe "declare/2" do
    test "refuses to run against a module that is no longer being compiled" do
      assert_raise ArgumentError, ~r/still being compiled/, fn ->
        Declaration.declare(Enum, deps: [])
      end
    end

    test "refuses exports outside the boundary namespace" do
      assert_raise ArgumentError, ~r/nested under the boundary's own namespace/, fn ->
        defmodule Declared do
          Declaration.declare(__MODULE__, exports: [Enum])
        end
      end
    end
  end
end
