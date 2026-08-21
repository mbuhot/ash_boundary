defmodule ExportedVsInternal.Storefront.Listing do
  @moduledoc false

  use Ash.Resource,
    domain: ExportedVsInternal.Storefront,
    data_layer: Ash.DataLayer.Ets

  alias ExportedVsInternal.Storefront.Calculations.SalePrice

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id
    attribute :headline, :string, allow_nil?: false, public?: true
    attribute :product_id, :uuid, allow_nil?: false, public?: true
  end

  relationships do
    # A relationship into another domain's internal resource is an alias reference, which
    # `boundary` does not check by default. This compiles with no `deps` entry naming
    # `Catalog` for it, and no export from `Catalog` for `InternalPricing`.
    belongs_to :pricing, ExportedVsInternal.Catalog.InternalPricing, writable?: false
  end

  calculations do
    calculate :sale_price, :float, SalePrice do
      public? true
    end
  end

  actions do
    defaults [:read, create: [:headline, :product_id]]
  end
end
