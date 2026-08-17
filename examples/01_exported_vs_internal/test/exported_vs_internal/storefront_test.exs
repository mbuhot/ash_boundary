defmodule ExportedVsInternal.StorefrontTest do
  use ExUnit.Case, async: true

  alias ExportedVsInternal.Storefront

  test "creating and fetching a product through the domain's exported interface works" do
    product = Storefront.create_and_fetch("Widget", 9.99)

    assert product.name == "Widget"
    assert product.price == 9.99
  end
end
