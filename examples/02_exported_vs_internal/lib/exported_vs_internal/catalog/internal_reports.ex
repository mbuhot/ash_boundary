defmodule ExportedVsInternal.Catalog.InternalReports do
  @moduledoc """
  Pricing reports for the catalog domain.
  """

  alias ExportedVsInternal.Catalog.InternalPricing

  @doc """
  Records a cost/margin pair for `sku` and returns the computed sale price.
  """
  @spec sale_price_for(String.t(), float(), float()) :: float()
  def sale_price_for(sku, cost, margin) do
    InternalPricing.record!(%{sku: sku, cost: cost, margin: margin})
    pricing = InternalPricing.calculate!(sku)
    pricing.sale_price
  end
end
