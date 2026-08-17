defmodule AshBoundary.DeclarationTest do
  use ExUnit.Case, async: true

  alias AshBoundary.Declaration
  alias AshBoundary.Test.Blog

  doctest AshBoundary.Declaration

  describe "the declaration installed by the transformer" do
    test "matches the shape `use Boundary` would have produced" do
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
      # Domains never reach this: `AshBoundary.Transformers.ValidateDomain` rejects an
      # un-nested resource first, with an error that explains itself. This is the
      # backstop for anything calling `declare/2` directly.
      assert_raise ArgumentError, ~r/nested under the boundary's own namespace/, fn ->
        defmodule Declared do
          Declaration.declare(__MODULE__, exports: [Enum])
        end
      end
    end
  end
end
