defmodule ExportedVsInternal.Catalog.InternalReports do
  @moduledoc """
  Lives *inside* `ExportedVsInternal.Catalog`'s own namespace and calls
  `InternalPricing`'s resource-level code interface directly — `record!/1` then
  `calculate!/1`. `boundary` classifies this module as belonging to the
  `ExportedVsInternal.Catalog` boundary (it nests under `ExportedVsInternal.Catalog.*`),
  the same boundary that owns `InternalPricing`, so the reference is never even a
  candidate for a violation: `boundary` only checks references that *cross* a boundary
  line, and a module calling another module in its own boundary never crosses one.

  This is the "internal resource's interface still works" half of what sample project 2
  demonstrates — compare `ExportedVsInternal.Storefront`, which lives *outside* this
  namespace and is restricted to the domain's exported interface only.
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
