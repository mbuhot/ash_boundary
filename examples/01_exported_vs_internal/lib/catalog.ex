defmodule Catalog do
  @moduledoc """
  The catalog domain.
  """

  use Ash.Domain, extensions: [AshBoundary]

  resources do
    resource Catalog.Product do
      define :create_product, action: :create
      define :get_product, action: :read, get_by: [:id]
    end

    resource Catalog.InternalPricing
  end
end
