defmodule ExportedVsInternal.Catalog.InternalReports do
  @moduledoc """
  Sits inside `ExportedVsInternal.Catalog`'s own namespace. Calls `InternalPricing`'s
  resource-level code interface directly, `record!/1` then `calculate!/1`. `boundary`
  classifies this module as part of the `ExportedVsInternal.Catalog` boundary, because
  it nests under `ExportedVsInternal.Catalog.*`. This is the same boundary that owns
  `InternalPricing`. The reference stays inside one boundary, so it is never a candidate
  for a violation. `boundary` checks only references that cross a boundary line.

  Compare `ExportedVsInternal.Storefront`, which sits outside this namespace and calls
  only the domain's exported interface.
  """

  alias ExportedVsInternal.Catalog.InternalPricing

  @doc """
  Books a cost/margin pair for `sku` and immediately reads back the computed
  `sale_price` — entirely through `InternalPricing`'s own `code_interface`, called from
  within the domain that owns it.
  """
  @spec sale_price_for(String.t(), float(), float()) :: float()
  def sale_price_for(sku, cost, margin) do
    InternalPricing.record!(%{sku: sku, cost: cost, margin: margin})
    pricing = InternalPricing.calculate!(sku)
    pricing.sale_price
  end
end
