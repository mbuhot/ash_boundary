defmodule ExportedVsInternal.StorefrontTest do
  @moduledoc """
  Lives outside `ExportedVsInternal.Catalog`'s namespace, same as the module under
  test — this is the proof that the *exported* side of the distinction works: a real
  module, outside the domain, genuinely calling the domain's exported code interface,
  run for real by `mix test` against the ETS data layer.
  """

  use ExUnit.Case, async: true

  alias ExportedVsInternal.Storefront

  test "creating and fetching a product through the domain's exported interface works" do
    product = Storefront.create_and_fetch("Widget", 9.99)

    assert product.name == "Widget"
    assert product.price == 9.99
  end
end
