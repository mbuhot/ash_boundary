defmodule ExportedVsInternal.Catalog.Product do
  @moduledoc """
  Exported: has a domain-level `define` in `ExportedVsInternal.Catalog`'s `resources`
  block, so `AshBoundary` includes it in the domain's computed `exports`. Code outside
  `ExportedVsInternal.Catalog.*` may reference this module directly, or go through the
  domain's code interface (`ExportedVsInternal.Catalog.create_product!/1`,
  `ExportedVsInternal.Catalog.get_product!/1`) — see `ExportedVsInternal.Storefront`,
  which does the latter.
  """

  use Ash.Resource,
    domain: ExportedVsInternal.Catalog,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :price, :float, allow_nil?: false, public?: true
  end

  actions do
    defaults [:read, create: [:name, :price]]
  end
end
