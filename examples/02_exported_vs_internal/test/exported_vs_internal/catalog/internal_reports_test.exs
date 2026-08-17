defmodule ExportedVsInternal.Catalog.InternalReportsTest do
  @moduledoc """
  Lives *inside* `ExportedVsInternal.Catalog`'s namespace, same as the module under
  test — this is the proof that the *internal* side of the distinction still works
  perfectly well when called from where `boundary` actually permits it: a real module,
  inside the domain, genuinely calling `InternalPricing`'s own resource-level code
  interface, run for real by `mix test` against the ETS data layer.

  This test existing alongside `ExportedVsInternal.StorefrontTest` is the whole point of
  this example: both the exported resource's domain-level interface and the internal
  resource's own interface return real data — the only difference is *where the caller
  is allowed to stand*, not whether the callee works.
  """

  use ExUnit.Case, async: true

  alias ExportedVsInternal.Catalog.InternalReports

  test "booking a cost/margin pair and reading back its computed sale price works" do
    sale_price = InternalReports.sale_price_for("sku-1", 10.0, 0.5)

    assert sale_price == 15.0
  end
end
