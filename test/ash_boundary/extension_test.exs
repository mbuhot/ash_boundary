defmodule AshBoundary.ExtensionTest do
  use ExUnit.Case, async: true

  alias AshBoundary.Declaration
  alias AshBoundary.Info
  alias AshBoundary.Test.Blog
  alias AshBoundary.Test.Compile

  doctest AshBoundary.Info

  describe "a domain extended with AshBoundary" do
    test "is a boundary as far as `boundary` itself is concerned" do
      # `Boundary.Definition.get/2` with no definition cache is the path `boundary` takes
      # for an already-compiled module: it reads the persisted attribute off the beam.
      # Nothing about AshBoundary is involved in the answer.
      assert definition = Boundary.Definition.get(Blog, nil)
      assert definition.app == :ash_boundary
      assert definition.check.in
      assert definition.check.out
      assert definition.errors == []
    end

    test "needs no `boundary` section, and then depends on nothing" do
      [domain] =
        Compile.modules("""
        defmodule AshBoundary.Test.NoSection do
          use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

          resources do
          end
        end
        """)

      # `Boundary.Definition.get/2` reads object code off disk, which a module compiled
      # into memory does not have, so read the persisted attribute directly.
      assert Keyword.fetch!(Declaration.definition(domain).opts, :deps) == []
      assert Info.deps(domain) == []
    end
  end

  describe "computed exports" do
    test "a resource with a domain-level define is exported" do
      assert Blog.Post in Boundary.Definition.get(Blog, nil).exports
    end

    test "a resource whose code interface lives on the resource stays internal" do
      # `Comment` has `code_interface do define :read_comments end` on the resource
      # module, and no `define` under `resource` in the domain. That is the whole
      # distinction: declaring the code interface on the domain is what makes a resource
      # public.
      assert Ash.Resource.Info.interfaces(Blog.Comment) != []
      refute Blog.Comment in Boundary.Definition.get(Blog, nil).exports
    end

    test "a resource with no code interface anywhere also stays internal" do
      # `Draft` has neither a domain-level `define` nor a resource-level
      # `code_interface`. It is a simpler case than `Comment` above (no code interface
      # at all, rather than one that just lives in the wrong place), and should be
      # excluded from exports for the same reason: no domain-level `define`.
      assert Ash.Resource.Info.interfaces(Blog.Draft) == []
      refute Blog.Draft in Boundary.Definition.get(Blog, nil).exports
    end

    test "a domain-level `define` and a resource-level `code_interface` coexist without conflict" do
      # `Tag` has both a domain-level `define` (exporting it) and its own
      # resource-level `code_interface`. Neither one excludes the other.
      assert Ash.Resource.Info.interfaces(Blog.Tag) != []
      assert Blog.Tag in Boundary.Definition.get(Blog, nil).exports
    end

    test "the exports are exactly the domain and its publicly-defined resources" do
      assert Info.exports(Blog) == [Blog, Blog.Post, Blog.Tag]
    end

    test "the boundary root is not listed, because `boundary` exports it implicitly" do
      refute Blog in Boundary.Definition.get(Blog, nil).exports
    end
  end

  describe "the `boundary` section" do
    test "declared deps survive the round trip" do
      assert Boundary.Definition.get(AshBoundary.Test.Reports, nil).deps == [{Blog, :runtime}]
    end

    test "a dep can name a type, narrowing it to compile-time references only" do
      # `:compile` restricts rather than widens: a bare module (`{Blog, :runtime}` above)
      # already permits every kind of reference, while `{Blog, :compile}` makes an
      # ordinary runtime call into `Blog` a violation.
      assert Boundary.Definition.get(AshBoundary.Test.Archive, nil).deps == [{Blog, :compile}]
    end

    test "`deps` is readable back off the domain" do
      assert Info.deps(AshBoundary.Test.Reports) == [Blog]
      assert Info.deps(AshBoundary.Test.Archive) == [{Blog, :compile}]
      assert Info.dep_modules(AshBoundary.Test.Archive) == [Blog]
    end

    test "a domain can list more than one dep, and each survives the round trip" do
      # `Dashboard` depends on two independent domains at once (`Blog` and
      # `Analytics`), each with its own resources and exports computed
      # independently. This is the composition case beyond a single dependency.
      assert Info.deps(AshBoundary.Test.Dashboard) == [
               AshBoundary.Test.Blog,
               AshBoundary.Test.Analytics
             ]

      assert Info.dep_modules(AshBoundary.Test.Dashboard) == [
               AshBoundary.Test.Blog,
               AshBoundary.Test.Analytics
             ]

      assert Boundary.Definition.get(AshBoundary.Test.Dashboard, nil).deps == [
               {AshBoundary.Test.Blog, :runtime},
               {AshBoundary.Test.Analytics, :runtime}
             ]
    end

    test "the idiomatic parens-free form survives `mix format`" do
      # `.formatter.exs` carries the `deps: 1` entry `mix spark.formatter` generates, and
      # exports it to consuming apps. Without it, `deps [Foo]` would be rewritten to
      # `deps([Foo])` on every format.
      source = """
      boundary do
        deps [MyApp.Accounts, {MyApp.Codegen, :compile}]
      end
      """

      assert Code.format_string!(source, locals_without_parens: locals_without_parens())
             |> IO.iodata_to_binary() == String.trim_trailing(source)
    end
  end

  defp locals_without_parens do
    {config, _binding} = Code.eval_file(".formatter.exs")

    Keyword.fetch!(config, :locals_without_parens)
  end
end
