defmodule Storefront do
  @moduledoc """
  The storefront domain.
  """

  use Ash.Domain, extensions: [AshBoundary]

  boundary do
    deps [Catalog]
  end

  resources do
  end

  @doc """
  Creates a product and reads it back.
  """
  @spec create_and_fetch(String.t(), float()) :: Catalog.Product.t()
  def create_and_fetch(name, price) do
    product = Catalog.create_product!(%{name: name, price: price})

    # A violation: InternalPricing has a code interface, and Catalog does not export it.
    # Catalog.InternalPricing.calculate!(name)
    Catalog.get_product!(product.id)
  end
end
