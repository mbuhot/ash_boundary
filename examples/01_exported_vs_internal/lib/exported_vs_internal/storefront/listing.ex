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

    # belongs_to :pricing, ExportedVsInternal.Catalog.InternalPricing is a violation: it names
    # Catalog's resource module directly. The calculation below reaches Catalog's exported
    # interface instead.
    attribute :product_id, :uuid, allow_nil?: false, public?: true
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
