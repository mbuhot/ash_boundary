defmodule Catalog.InternalReportsTest do
  use ExUnit.Case, async: true

  alias Catalog.InternalReports

  test "booking a cost/margin pair and reading back its computed sale price works" do
    sale_price = InternalReports.sale_price_for("sku-1", 10.0, 0.5)

    assert sale_price == 15.0
  end
end
