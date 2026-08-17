defmodule ExportedVsInternal.Storefront do
  @moduledoc """
  Sits entirely outside `ExportedVsInternal.Catalog`'s namespace. Calls into `Catalog`
  only through the domain's exported code interface. `AshBoundary` leaves this call path
  unaffected, the same as `BasicBoundary.Reports` in example 1.

  This module cannot reach `ExportedVsInternal.Catalog.InternalPricing`, either its
  module directly or its own `code_interface` functions, even though those functions
  are real, generated, and callable. See the README for that reproduced as a real
  compiler warning.
  """

  alias ExportedVsInternal.Catalog

  @doc """
  Creates a product and immediately reads it back, entirely through
  `ExportedVsInternal.Catalog`'s domain-level code interface.
  """
  @spec create_and_fetch(String.t(), float()) :: ExportedVsInternal.Catalog.Product.t()
  def create_and_fetch(name, price) do
    product = Catalog.create_product!(%{name: name, price: price})
    Catalog.get_product!(product.id)
  end
end
