defmodule AshBoundary.ReadOnlyRelationshipTest do
  # Installs a compiler tracer process-globally, so it must not race other tests.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias AshBoundary.Declaration
  alias AshBoundary.Info
  alias AshBoundary.Test.Blog
  alias AshBoundary.Test.BoundaryCheck
  alias AshBoundary.Test.Compile
  alias AshBoundary.Test.Fulfilment
  alias AshBoundary.Test.Ledger
  alias AshBoundary.Test.Orders
  alias AshBoundary.Test.Register
  alias Spark.Error.DslError

  @world [
    AshBoundary.Test.Blog,
    AshBoundary.Test.Blog.Post,
    AshBoundary.Test.Blog.Comment,
    AshBoundary.Test.Blog.Draft,
    AshBoundary.Test.Blog.Tag,
    AshBoundary.Test.Blog.PostStatus,
    AshBoundary.Test.Blog.DraftStatus,
    AshBoundary.Test.Ledger,
    AshBoundary.Test.Ledger.Entry,
    AshBoundary.Test.Ledger.Adjustment,
    AshBoundary.Test.Register,
    AshBoundary.Test.Register.Line,
    AshBoundary.Test.Orders,
    AshBoundary.Test.Orders.Order,
    AshBoundary.Test.Fulfilment,
    AshBoundary.Test.Fulfilment.Shipment
  ]

  describe "the generated declaration" do
    test "names each read-only target in `dirty_xrefs`, and declares no dep" do
      opts = Declaration.definition(Fulfilment).opts

      assert Keyword.fetch!(opts, :dirty_xrefs) == [Orders.Order]
      assert Keyword.fetch!(opts, :deps) == []
    end

    test "leaves `dirty_xrefs` empty for a writable relationship" do
      assert Info.read_only_relationships(Orders) == []
      assert Keyword.fetch!(Declaration.definition(Orders).opts, :dirty_xrefs) == []
    end

    test "leaves `dirty_xrefs` empty without the option" do
      refute Info.allow_read_only_relationships?(Register)
      assert Info.read_only_relationship_targets(Register) == []
      assert Keyword.fetch!(Declaration.definition(Register).opts, :dirty_xrefs) == []
    end

    test "names only the read-only target of a domain declaring both kinds" do
      assert Info.read_only_relationship_targets(Ledger) == [Blog.Post]
    end

    test "reads `writable?` alone, so a writable foreign key still qualifies" do
      Compile.modules(
        source(
          AshBoundary.Test.Invoicing.Line,
          AshBoundary.Test.Invoicing,
          "belongs_to :post, AshBoundary.Test.Blog.Post, writable?: false, attribute_writable?: true"
        ) <> domain_source(AshBoundary.Test.Invoicing, AshBoundary.Test.Invoicing.Line)
      )

      assert Ash.Resource.Info.relationship(AshBoundary.Test.Invoicing.Line, :post).attribute_writable?

      assert Info.read_only_relationship_targets(AshBoundary.Test.Invoicing) == [Blog.Post]
    end
  end

  describe "a read-only relationship into another domain" do
    test "is permitted with no dep, when the target is exported" do
      references = references(Ledger.Entry, read_only_post())

      assert [%{type: :alias_reference}] = Enum.filter(references, &(&1.to == Blog.Post))
      assert BoundaryCheck.reference_errors(@world, references) == []
    end

    test "is a violation when the same domain declares it writably" do
      references =
        references(
          Ledger.Adjustment,
          source(Ledger.Adjustment, Ledger, "belongs_to :tag, AshBoundary.Test.Blog.Tag")
        )

      assert BoundaryCheck.reference_errors(@world, references) == [
               {:normal, Ledger.Adjustment, Blog.Tag}
             ]
    end

    test "is a violation without `allow_read_only_relationships?`" do
      references =
        references(
          Register.Line,
          source(
            Register.Line,
            Register,
            "belongs_to :post, AshBoundary.Test.Blog.Post, writable?: false"
          )
        )

      assert BoundaryCheck.reference_errors(@world, references) == [
               {:normal, Register.Line, Blog.Post}
             ]
    end
  end

  describe "a two-way relationship" do
    test "is permitted in both directions" do
      references = two_way_references()

      assert Enum.any?(references, &(&1.to == Orders.Order))
      assert Enum.any?(references, &(&1.to == Fulfilment.Shipment))
      assert BoundaryCheck.reference_errors(@world, references) == []
    end

    test "leaves `boundary` no error to report anywhere in the world" do
      references = references(Ledger.Entry, read_only_post()) ++ two_way_references()

      assert BoundaryCheck.errors(@world, references) == []
    end

    @tag :tmp_dir
    test "compiles from scratch, with the dep declared on the writable side only", %{
      tmp_dir: tmp_dir
    } do
      sources =
        two_way_sources(
          AshBoundary.Test.Depot,
          AshBoundary.Test.Freight,
          "define :get_consignment, action: :read"
        )

      refute Compile.parallel_error(tmp_dir, sources)

      assert Info.deps(AshBoundary.Test.Depot) == [AshBoundary.Test.Freight]
      assert Info.deps(AshBoundary.Test.Freight) == []

      assert Info.read_only_relationship_targets(AshBoundary.Test.Freight) == [
               AshBoundary.Test.Depot.Consignment
             ]
    end
  end

  describe "a read-only target its own domain does not export" do
    setup do
      error =
        Compile.error(
          source(
            AshBoundary.Test.Audit.Trail,
            AshBoundary.Test.Audit,
            "belongs_to :comment, AshBoundary.Test.Blog.Comment, writable?: false"
          ) <> domain_source(AshBoundary.Test.Audit, AshBoundary.Test.Audit.Trail)
        )

      %{error: error, message: Exception.message(error)}
    end

    test "is rejected", %{error: error} do
      assert %DslError{path: [:boundary, :allow_read_only_relationships?]} = error
    end

    test "names the resource, its domain, and a fix", %{message: message} do
      assert message =~ "AshBoundary.Test.Blog.Comment is the destination of the read-only"
      assert message =~ "`:comment` on AshBoundary.Test.Audit.Trail"
      assert message =~ "is not exported by AshBoundary.Test.Blog"
      assert message =~ "Add a `define` for AshBoundary.Test.Blog.Comment"
    end

    @tag :tmp_dir
    test "is rejected in a two-way pair as well, rather than skipped", %{tmp_dir: tmp_dir} do
      message =
        Compile.parallel_error(
          tmp_dir,
          two_way_sources(AshBoundary.Test.Yard, AshBoundary.Test.Haulage, "")
        )

      assert message =~ "is not exported by AshBoundary.Test.Yard"
      refute message =~ "depend on each other"
    end
  end

  describe "a target that is read-only from one relationship and writable from another" do
    setup do
      error =
        Compile.error(
          source(AshBoundary.Test.Mixed.Entry, AshBoundary.Test.Mixed, """
          belongs_to :post, AshBoundary.Test.Blog.Post, writable?: false
              belongs_to :edited_post, AshBoundary.Test.Blog.Post
          """) <> domain_source(AshBoundary.Test.Mixed, AshBoundary.Test.Mixed.Entry)
        )

      %{error: error, message: Exception.message(error)}
    end

    test "is rejected", %{error: error} do
      assert %DslError{path: [:boundary, :allow_read_only_relationships?]} = error
    end

    test "names both relationships, their resources, and the dep to add", %{message: message} do
      assert message =~
               "AshBoundary.Test.Blog.Post is the destination of the read-only relationship"

      assert message =~ "`:post` on AshBoundary.Test.Mixed.Entry"
      assert message =~ "writable belongs_to `:edited_post` on AshBoundary.Test.Mixed.Entry"
      assert message =~ "exempts a target module rather than a single relationship"
      assert message =~ "Name the domain that owns AshBoundary.Test.Blog.Post"
    end

    test "is rejected across two resources of the same domain" do
      error =
        Compile.error(
          source(
            AshBoundary.Test.Split.Reader,
            AshBoundary.Test.Split,
            "belongs_to :post, AshBoundary.Test.Blog.Post, writable?: false"
          ) <>
            source(
              AshBoundary.Test.Split.Writer,
              AshBoundary.Test.Split,
              "belongs_to :post, AshBoundary.Test.Blog.Post"
            ) <>
            domain_source(AshBoundary.Test.Split, [
              AshBoundary.Test.Split.Reader,
              AshBoundary.Test.Split.Writer
            ])
        )

      assert %DslError{path: [:boundary, :allow_read_only_relationships?]} = error
      assert Exception.message(error) =~ "`:post` on AshBoundary.Test.Split.Reader"
      assert Exception.message(error) =~ "`:post` on AshBoundary.Test.Split.Writer"
    end

    test "is rejected when the writer is a `many_to_many`" do
      error =
        Compile.error(
          """
          defmodule AshBoundary.Test.Joined.Link do
            use Ash.Resource, domain: AshBoundary.Test.Joined

            attributes do
              uuid_primary_key :id
              attribute :entry_id, :uuid
              attribute :post_id, :uuid
            end

            actions do
              defaults [:read]
            end
          end

          """ <>
            source(AshBoundary.Test.Joined.Entry, AshBoundary.Test.Joined, """
            belongs_to :post, AshBoundary.Test.Blog.Post, writable?: false

                many_to_many :posts, AshBoundary.Test.Blog.Post,
                  through: AshBoundary.Test.Joined.Link,
                  source_attribute_on_join_resource: :entry_id,
                  destination_attribute_on_join_resource: :post_id
            """) <>
            domain_source(AshBoundary.Test.Joined, [
              AshBoundary.Test.Joined.Link,
              AshBoundary.Test.Joined.Entry
            ])
        )

      assert %DslError{path: [:boundary, :allow_read_only_relationships?]} = error

      assert Exception.message(error) =~
               "writable many_to_many `:posts` on AshBoundary.Test.Joined.Entry"
    end

    test "leaves a lone read-only relationship to that target alone" do
      refute Compile.error(
               source(
                 AshBoundary.Test.Sole.Entry,
                 AshBoundary.Test.Sole,
                 "belongs_to :post, AshBoundary.Test.Blog.Post, writable?: false"
               ) <> domain_source(AshBoundary.Test.Sole, AshBoundary.Test.Sole.Entry)
             )

      assert Info.read_only_relationship_targets(AshBoundary.Test.Sole) == [Blog.Post]
    end
  end

  describe "a read-only target whose domain is not compiled yet" do
    test "is permitted, and its export goes unchecked" do
      refute Compile.error(
               source(
                 AshBoundary.Test.Pending.Item,
                 AshBoundary.Test.Pending,
                 "belongs_to :thing, AshBoundary.Test.Later.Thing, writable?: false"
               ) <>
                 domain_source(AshBoundary.Test.Pending, AshBoundary.Test.Pending.Item) <>
                 source(AshBoundary.Test.Later.Thing, AshBoundary.Test.Later, "") <>
                 """
                 defmodule AshBoundary.Test.Later do
                   use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

                   resources do
                     resource AshBoundary.Test.Later.Thing
                   end
                 end
                 """
             )

      refute AshBoundary.Test.Later.Thing in Info.exports(AshBoundary.Test.Later)
    end
  end

  defp references(module, source) do
    {references, _output} =
      with_io(:stderr, fn -> BoundaryCheck.capture_references(module, source) end)

    references
  end

  defp two_way_references do
    references(Fulfilment.Shipment, read_only_order()) ++
      references(
        Orders.Order,
        source(Orders.Order, Orders, "belongs_to :shipment, AshBoundary.Test.Fulfilment.Shipment")
      )
  end

  defp read_only_post do
    source(Ledger.Entry, Ledger, "belongs_to :post, AshBoundary.Test.Blog.Post, writable?: false")
  end

  defp read_only_order do
    source(
      Fulfilment.Shipment,
      Fulfilment,
      "belongs_to :order, AshBoundary.Test.Orders.Order, writable?: false"
    )
  end

  defp two_way_sources(writable, read_only, define) do
    consignment = Module.concat(writable, Consignment)
    parcel = Module.concat(read_only, Parcel)

    [
      {"writable.ex",
       source(consignment, writable, "belongs_to :parcel, #{inspect(parcel)}") <>
         """
         defmodule #{inspect(writable)} do
           use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

           boundary do
             deps [#{inspect(read_only)}]
           end

           resources do
             resource #{inspect(consignment)} do
               #{define}
             end
           end
         end
         """},
      {"read_only.ex",
       source(
         parcel,
         read_only,
         "belongs_to :consignment, #{inspect(consignment)}, writable?: false"
       ) <>
         """
         defmodule #{inspect(read_only)} do
           use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

           boundary do
             allow_read_only_relationships? true
           end

           resources do
             resource #{inspect(parcel)} do
               define :get_parcel, action: :read
             end
           end
         end
         """}
    ]
  end

  defp source(module, domain, relationship) do
    """
    defmodule #{inspect(module)} do
      use Ash.Resource, domain: #{inspect(domain)}

      attributes do
        uuid_primary_key :id
      end

      relationships do
        #{relationship}
      end

      actions do
        defaults [:read]
      end
    end

    """
  end

  defp domain_source(domain, resources) do
    entries =
      resources
      |> List.wrap()
      |> Enum.map_join("\n", &"    resource #{inspect(&1)}")

    """
    defmodule #{inspect(domain)} do
      use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

      boundary do
        allow_read_only_relationships? true
      end

      resources do
    #{entries}
      end
    end

    """
  end
end
