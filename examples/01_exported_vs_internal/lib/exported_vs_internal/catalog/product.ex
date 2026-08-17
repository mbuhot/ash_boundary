defmodule ExportedVsInternal.Catalog.Product do
  @moduledoc false

  use Ash.Resource,
    domain: ExportedVsInternal.Catalog,
    data_layer: Ash.DataLayer.Ets

  alias ExportedVsInternal.Catalog.InternalPricing

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
  end

  actions do
    defaults [:read, create: [:name]]

    action :price_product, :float do
      argument :product_id, :uuid, allow_nil?: false
      argument :cost, :float, allow_nil?: false
      argument :margin, :float, allow_nil?: false

      run fn input, _context ->
        InternalPricing.record!(%{
          product_id: input.arguments.product_id,
          cost: input.arguments.cost,
          margin: input.arguments.margin
        })

        {:ok, InternalPricing.calculate!(input.arguments.product_id).sale_price}
      end
    end

    action :sale_prices, :map do
      argument :product_ids, {:array, :uuid}, allow_nil?: false

      run fn input, _context ->
        prices =
          input.arguments.product_ids
          |> Enum.uniq()
          |> InternalPricing.for_products!()
          |> Map.new(&{&1.product_id, &1.sale_price})

        {:ok, prices}
      end
    end
  end
end
