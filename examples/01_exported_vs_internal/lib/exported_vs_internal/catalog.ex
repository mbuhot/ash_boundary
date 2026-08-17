defmodule ExportedVsInternal.Catalog do
  @moduledoc """
  The catalog domain.
  """

  use Ash.Domain, extensions: [AshBoundary]

  resources do
    resource ExportedVsInternal.Catalog.Product do
      define :create_product, action: :create
      define :get_product, action: :read, get_by: [:id]
      define :price_product, action: :price_product, args: [:product_id, :cost, :margin]
      define :product_sale_prices, action: :sale_prices, args: [:product_ids]
    end

    resource ExportedVsInternal.Catalog.InternalPricing
  end
end
