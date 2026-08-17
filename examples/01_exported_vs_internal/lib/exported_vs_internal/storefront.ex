defmodule ExportedVsInternal.Storefront do
  @moduledoc """
  The storefront domain.
  """

  use Ash.Domain, extensions: [AshBoundary]

  boundary do
    deps [ExportedVsInternal.Catalog]
  end

  resources do
    resource ExportedVsInternal.Storefront.Listing do
      define :create_listing, action: :create
      define :get_listing, action: :read, get_by: [:id]
    end
  end
end
