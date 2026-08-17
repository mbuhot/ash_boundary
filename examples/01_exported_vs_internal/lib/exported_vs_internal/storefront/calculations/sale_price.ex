defmodule ExportedVsInternal.Storefront.Calculations.SalePrice do
  @moduledoc false

  use Ash.Resource.Calculation

  alias ExportedVsInternal.Catalog

  @impl Ash.Resource.Calculation
  def load(_query, _opts, _context), do: [:product_id]

  @impl Ash.Resource.Calculation
  def calculate(listings, _opts, _context) do
    product_ids = Enum.map(listings, & &1.product_id)

    # A violation: InternalPricing has a code interface, and Catalog does not export it.
    # Catalog.InternalPricing.for_products!(product_ids)
    prices = Catalog.product_sale_prices!(product_ids)

    {:ok, Enum.map(listings, &Map.get(prices, &1.product_id))}
  end
end
