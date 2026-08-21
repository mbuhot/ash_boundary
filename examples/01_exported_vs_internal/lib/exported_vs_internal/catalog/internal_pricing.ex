defmodule ExportedVsInternal.Catalog.InternalPricing do
  @moduledoc false

  use Ash.Resource,
    domain: ExportedVsInternal.Catalog,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id
    attribute :product_id, :uuid, allow_nil?: false, public?: true
    attribute :cost, :float, allow_nil?: false, public?: true
    attribute :margin, :float, allow_nil?: false, public?: true
  end

  relationships do
    # The reverse direction of the relationship on `Storefront.Listing`. `Catalog` declares
    # no `deps` on `Storefront` at all, and this still compiles: the same alias reference
    # rule applies in both directions.
    has_one :listing, ExportedVsInternal.Storefront.Listing, destination_attribute: :pricing_id
  end

  calculations do
    calculate :sale_price, :float, expr(cost * (1 + margin))
  end

  actions do
    defaults [:read, create: [:product_id, :cost, :margin]]

    read :by_product do
      get? true
      argument :product_id, :uuid, allow_nil?: false
      filter expr(product_id == ^arg(:product_id))
      prepare build(load: [:sale_price])
    end

    read :for_products do
      argument :product_ids, {:array, :uuid}, allow_nil?: false
      filter expr(product_id in ^arg(:product_ids))
      prepare build(load: [:sale_price])
    end
  end

  code_interface do
    define :record, action: :create
    define :calculate, action: :by_product, args: [:product_id]
    define :for_products, action: :for_products, args: [:product_ids]
  end
end
