defmodule ExportedVsInternal.Storefront.Calculations.SalePrice do
  @moduledoc false

  use Ash.Resource.Calculation

  alias ExportedVsInternal.Catalog

  @impl Ash.Resource.Calculation
  def load(_query, _opts, _context), do: [:product_id]

  @impl Ash.Resource.Calculation
  def calculate(listings, _opts, _context) do
    product_ids = Enum.map(listings, & &1.product_id)

    # Calling Catalog.InternalPricing is not allowed
    # prices = Map.new(product_ids, &{&1, Catalog.InternalPricing.calculate!(&1).sale_price})
    prices = Catalog.product_sale_prices!(product_ids)

    {:ok, Enum.map(listings, &Map.get(prices, &1.product_id))}
  end
end
