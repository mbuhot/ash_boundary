defmodule ExportedVsInternal.Storefront do
  @moduledoc """
  Lives outside `ExportedVsInternal.Catalog`'s namespace entirely, and calls into it
  only through the domain's exported code interface — the happy path `AshBoundary`
  is meant to leave completely unaffected, same as `BasicBoundary.Reports` in sample
  project 1.

  Nothing here can reach `ExportedVsInternal.Catalog.InternalPricing` — not its module
  directly, and not its own `code_interface` functions either, despite those being
  real, generated, callable functions. See the README for that reproduced as a real
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
