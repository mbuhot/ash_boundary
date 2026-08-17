defmodule ExportedVsInternal.Catalog.InternalReportsTest do
  use ExUnit.Case, async: true

  alias ExportedVsInternal.Catalog
  alias ExportedVsInternal.Catalog.InternalReports

  test "booking a cost/margin pair and reading back its computed sale price works" do
    product = Catalog.create_product!(%{name: "Widget"})

    assert InternalReports.sale_price_for(product.id, 10.0, 0.5) == 15.0
  end
end
