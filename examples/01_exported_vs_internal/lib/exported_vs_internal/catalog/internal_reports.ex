defmodule ExportedVsInternal.Catalog.InternalReports do
  @moduledoc """
  Pricing reports for the catalog domain.
  """

  alias ExportedVsInternal.Catalog.InternalPricing

  @doc """
  Records a cost/margin pair for `product_id` and returns the computed sale price.
  """
  @spec sale_price_for(Ash.UUID.t(), float(), float()) :: float()
  def sale_price_for(product_id, cost, margin) do
    InternalPricing.record!(%{product_id: product_id, cost: cost, margin: margin})
    pricing = InternalPricing.calculate!(product_id)
    pricing.sale_price
  end
end
