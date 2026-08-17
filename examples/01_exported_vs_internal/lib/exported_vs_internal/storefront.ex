defmodule ExportedVsInternal.Storefront do
  @moduledoc """
  Storefront code that reads the catalog.
  """

  alias ExportedVsInternal.Catalog

  @doc """
  Creates a product and reads it back.
  """
  @spec create_and_fetch(String.t(), float()) :: ExportedVsInternal.Catalog.Product.t()
  def create_and_fetch(name, price) do
    product = Catalog.create_product!(%{name: name, price: price})
    Catalog.get_product!(product.id)
  end
end
