defmodule AshBoundary.ValidateDomainTest do
  use ExUnit.Case, async: true

  alias AshBoundary.Test.Compile
  alias Spark.Error.DslError

  describe "a hand-written `use Boundary` on the same domain" do
    test "is rejected when it comes after the extension" do
      error =
        Compile.error("""
        defmodule AshBoundary.Test.Invalid.ManualAfter do
          use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false
          use Boundary

          resources do
          end
        end
        """)

      assert %DslError{path: [:boundary]} = error
      assert Exception.message(error) =~ "calls `use Boundary` as well as being extended"
      assert Exception.message(error) =~ "Remove the `use Boundary` line."
    end

    test "is rejected when it comes before the extension" do
      # The failure this guards against is order-dependent: whichever `@before_compile`
      # hook runs last wins, so one ordering silently drops AshBoundary's computed
      # declaration and the other silently drops the user's. Both must be caught.
      error =
        Compile.error("""
        defmodule AshBoundary.Test.Invalid.ManualBefore do
          use Boundary, deps: [], exports: []
          use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

          resources do
          end
        end
        """)

      assert %DslError{path: [:boundary]} = error
      assert Exception.message(error) =~ "calls `use Boundary` as well as being extended"
    end

    test "the domain compiles fine with either one on its own" do
      refute Compile.error("""
             defmodule AshBoundary.Test.Invalid.ExtensionOnly do
               use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

               resources do
               end
             end
             """)

      refute Compile.error("""
             defmodule AshBoundary.Test.Invalid.BoundaryOnly do
               use Ash.Domain, validate_config_inclusion?: false
               use Boundary

               resources do
               end
             end
             """)
    end
  end

  describe "a resource outside the domain's namespace" do
    setup do
      error =
        Compile.error("""
        defmodule AshBoundary.Test.Elsewhere.Widget do
          use Ash.Resource, domain: AshBoundary.Test.Invalid.Unnested

          attributes do
            uuid_primary_key :id
          end
        end

        defmodule AshBoundary.Test.Invalid.Unnested do
          use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

          resources do
            resource AshBoundary.Test.Elsewhere.Widget
          end
        end
        """)

      %{error: error, message: Exception.message(error)}
    end

    test "is rejected", %{error: error} do
      assert %DslError{path: [:resources]} = error
    end

    test "names the resource, the domain, and a fix", %{message: message} do
      assert message =~ "AshBoundary.Test.Elsewhere.Widget"
      assert message =~ "AshBoundary.Test.Invalid.Unnested"
      assert message =~ "module-name nesting"
      assert message =~ "AshBoundary.Test.Invalid.Unnested.Widget"
    end

    test "does not leak `boundary`'s own wording", %{message: message} do
      # `AshBoundary.Declaration.declare/2` would raise about "boundary namespaces" here,
      # which means nothing to a reader who has not read boundary's source. Catching it
      # first is the entire point of this check.
      refute message =~ "cannot export"
    end

    test "is caught even though the resource has no domain-level define" do
      # An unexported resource never reaches `declare/2`'s own namespace check, so without
      # this check it would compile silently and simply never be protected.
      assert %DslError{path: [:resources]} =
               Compile.error("""
               defmodule AshBoundary.Test.Elsewhere.Gadget do
                 use Ash.Resource, domain: AshBoundary.Test.Invalid.UnnestedInternal

                 attributes do
                   uuid_primary_key :id
                 end

                 actions do
                   defaults [:read]
                 end
               end

               defmodule AshBoundary.Test.Invalid.UnnestedInternal do
                 use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

                 resources do
                   resource AshBoundary.Test.Elsewhere.Gadget do
                     define :get_gadget, action: :read
                   end
                 end
               end
               """)
    end

    test "deeper nesting under the domain is fine" do
      refute Compile.error("""
             defmodule AshBoundary.Test.Nested.Deeply.Nested.Thing do
               use Ash.Resource, domain: AshBoundary.Test.Nested

               attributes do
                 uuid_primary_key :id
               end
             end

             defmodule AshBoundary.Test.Nested do
               use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

               resources do
                 resource AshBoundary.Test.Nested.Deeply.Nested.Thing
               end
             end
             """)
    end
  end

  describe "an `exports` entry outside the domain's namespace" do
    setup do
      error =
        Compile.error("""
        defmodule AshBoundary.Test.Invalid.UnnestedExport do
          use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

          boundary do
            exports [AshBoundary.Test.Elsewhere.Status]
          end

          resources do
          end
        end
        """)

      %{error: error, message: Exception.message(error)}
    end

    test "is rejected", %{error: error} do
      assert %DslError{path: [:boundary, :exports]} = error
    end

    test "names the module, the domain, and a fix", %{message: message} do
      assert message =~ "The module AshBoundary.Test.Elsewhere.Status is not nested under"
      assert message =~ "AshBoundary.Test.Invalid.UnnestedExport"
      assert message =~ "module-name nesting"
      assert message =~ "Rename it to sit under"
    end

    test "does not leak `boundary`'s own wording", %{message: message} do
      refute message =~ "cannot export"
    end

    test "a module nested under the domain is fine" do
      refute Compile.error("""
             defmodule AshBoundary.Test.NestedExport.Status do
               use Ash.Type.Enum, values: [:on, :off]
             end

             defmodule AshBoundary.Test.NestedExport do
               use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

               boundary do
                 exports [AshBoundary.Test.NestedExport.Status]
               end

               resources do
               end
             end
             """)
    end
  end

  describe "an `exports` entry that names a resource of the domain" do
    setup do
      error =
        Compile.error("""
        defmodule AshBoundary.Test.Invalid.ExportedResource.Post do
          use Ash.Resource, domain: AshBoundary.Test.Invalid.ExportedResource

          attributes do
            uuid_primary_key :id
          end

          actions do
            defaults [:read]
          end
        end

        defmodule AshBoundary.Test.Invalid.ExportedResource do
          use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

          boundary do
            exports [AshBoundary.Test.Invalid.ExportedResource.Post]
          end

          resources do
            resource AshBoundary.Test.Invalid.ExportedResource.Post
          end
        end
        """)

      %{error: error, message: Exception.message(error)}
    end

    test "is rejected", %{error: error} do
      assert %DslError{path: [:boundary, :exports]} = error
    end

    test "points at `define` instead", %{message: message} do
      assert message =~ "AshBoundary.Test.Invalid.ExportedResource.Post is listed in `exports`"
      assert message =~ "a resource of AshBoundary.Test.Invalid.ExportedResource"
      assert message =~ "domain-level `define`"
      assert message =~ "Add a `define` to"
    end

    test "is rejected even when the resource already carries a define" do
      assert %DslError{path: [:boundary, :exports]} =
               Compile.error("""
               defmodule AshBoundary.Test.Invalid.DefinedResource.Post do
                 use Ash.Resource, domain: AshBoundary.Test.Invalid.DefinedResource

                 attributes do
                   uuid_primary_key :id
                 end

                 actions do
                   defaults [:read]
                 end
               end

               defmodule AshBoundary.Test.Invalid.DefinedResource do
                 use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

                 boundary do
                   exports [AshBoundary.Test.Invalid.DefinedResource.Post]
                 end

                 resources do
                   resource AshBoundary.Test.Invalid.DefinedResource.Post do
                     define :get_post, action: :read
                   end
                 end
               end
               """)
    end
  end

  describe "a `deps` entry that is not a boundary" do
    test "is rejected" do
      error =
        Compile.error("""
        defmodule AshBoundary.Test.Invalid.PlainDep do
          use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

          boundary do
            deps [Enum]
          end

          resources do
          end
        end
        """)

      assert %DslError{path: [:boundary, :deps]} = error
      assert Exception.message(error) =~ "Enum, which is not a boundary"
      assert Exception.message(error) =~ "add `extensions: [AshBoundary]`"
    end

    test "is rejected when it names a module that does not exist" do
      error =
        Compile.error("""
        defmodule AshBoundary.Test.Invalid.MissingDep do
          use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

          boundary do
            deps [AshBoundary.Test.NoSuchDomain]
          end

          resources do
          end
        end
        """)

      assert %DslError{path: [:boundary, :deps]} = error
      assert Exception.message(error) =~ "could not be loaded"
      assert Exception.message(error) =~ "check this one for a typo"
    end

    test "is rejected when a domain lists itself" do
      error =
        Compile.error("""
        defmodule AshBoundary.Test.Invalid.SelfDep do
          use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

          boundary do
            deps [__MODULE__]
          end

          resources do
          end
        end
        """)

      assert %DslError{path: [:boundary, :deps]} = error
      assert Exception.message(error) =~ "lists itself in `deps`"
    end

    test "an Ash.Domain without the extension is still not a boundary" do
      Compile.modules("""
      defmodule AshBoundary.Test.Invalid.Unextended do
        use Ash.Domain, validate_config_inclusion?: false

        resources do
        end
      end
      """)

      error =
        Compile.error("""
        defmodule AshBoundary.Test.Invalid.DependsOnUnextended do
          use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

          boundary do
            deps [AshBoundary.Test.Invalid.Unextended]
          end

          resources do
          end
        end
        """)

      assert %DslError{path: [:boundary, :deps]} = error
      assert Exception.message(error) =~ "which is not a boundary"
    end

    @tag :tmp_dir
    test "two domains depending on each other fail cleanly as a cycle", %{tmp_dir: tmp_dir} do
      # Checking a dep calls `Code.ensure_compiled/1`, so a mutual dependency is the one
      # case where the dep is real but unanswerable. Elixir breaks the cycle rather than
      # hanging, handing back `{:error, :unavailable}` — which must not be reported as
      # the missing-module "check this for a typo" case.
      message =
        Compile.parallel_error(tmp_dir, [
          {"cycle_a.ex",
           """
           defmodule AshBoundary.Test.Invalid.CycleA do
             use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

             boundary do
               deps [AshBoundary.Test.Invalid.CycleB]
             end

             resources do
             end
           end
           """},
          {"cycle_b.ex",
           """
           defmodule AshBoundary.Test.Invalid.CycleB do
             use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

             boundary do
               deps [AshBoundary.Test.Invalid.CycleA]
             end

             resources do
             end
           end
           """}
        ])

      assert message =~ "depend on each other"
      assert message =~ "AshBoundary.Test.Invalid.CycleA"
      assert message =~ "AshBoundary.Test.Invalid.CycleB"
      assert message =~ "Break the cycle"
      # Either side may be the one that loses the race, but neither may be blamed on a typo.
      refute message =~ "typo"
    end

    test "a plain `use Boundary` module is accepted, since it is a real boundary" do
      Compile.modules("""
      defmodule AshBoundary.Test.HandWritten do
        use Boundary
      end
      """)

      refute Compile.error("""
             defmodule AshBoundary.Test.Invalid.DependsOnHandWritten do
               use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

               boundary do
                 deps [AshBoundary.Test.HandWritten]
               end

               resources do
               end
             end
             """)
    end
  end
end
