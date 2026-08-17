defmodule ExportedVsInternal.StorefrontTest do
  use ExUnit.Case, async: true

  alias ExportedVsInternal.Catalog
  alias ExportedVsInternal.Storefront

  test "creating and fetching a product through the catalog's exported interface works" do
    product = Catalog.create_product!(%{name: "Widget"})

    assert Catalog.get_product!(product.id).name == "Widget"
  end

  test "a listing's sale price comes from the catalog's internal pricing resource" do
    product = Catalog.create_product!(%{name: "Widget"})
    Catalog.price_product!(product.id, 10.0, 0.5)

    listing = Storefront.create_listing!(%{headline: "On sale", product_id: product.id})

    assert %Ash.NotLoaded{} = listing.sale_price
    assert Storefront.get_listing!(listing.id, load: [:sale_price]).sale_price == 15.0
  end

  test "loading the calculation over a batch of listings resolves each one's own product" do
    widget = Catalog.create_product!(%{name: "Widget"})
    gadget = Catalog.create_product!(%{name: "Gadget"})

    Catalog.price_product!(widget.id, 10.0, 0.5)
    Catalog.price_product!(gadget.id, 100.0, 0.2)

    listings = [
      Storefront.create_listing!(%{headline: "Widget deal", product_id: widget.id}),
      Storefront.create_listing!(%{headline: "Gadget deal", product_id: gadget.id}),
      Storefront.create_listing!(%{headline: "Widget again", product_id: widget.id})
    ]

    assert listings
           |> Ash.load!([:sale_price])
           |> Enum.map(& &1.sale_price) == [15.0, 120.0, 15.0]
  end

  test "a listing for an unpriced product resolves to nil" do
    product = Catalog.create_product!(%{name: "Unpriced"})
    listing = Storefront.create_listing!(%{headline: "Coming soon", product_id: product.id})

    assert Storefront.get_listing!(listing.id, load: [:sale_price]).sale_price == nil
  end
end
