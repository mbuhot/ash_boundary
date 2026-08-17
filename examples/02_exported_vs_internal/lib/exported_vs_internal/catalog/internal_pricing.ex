defmodule ExportedVsInternal.Catalog.InternalPricing do
  @moduledoc """
  Internal resource. `ExportedVsInternal.Catalog`'s `resources` block names this
  resource with a bare `resource` entry. This entry has no domain-level `define`.
  `AshBoundary` leaves this resource out of the domain's computed `exports`. Exported
  status depends only on the domain-level `define`. Exported status does not depend on
  whether the resource has a code interface.

  This resource has a code interface. The `code_interface` block below defines
  `record/1`, which wraps the `:create` action, and `calculate/1`, which wraps the
  `:by_sku` read action and its `sale_price` calculation. Both are ordinary generated
  functions on this module. Both are as real and as callable as `Product`'s functions.
  `boundary` treats a code interface function the same as any other function on a
  module. `boundary` checks only whether the module is exported by its owner boundary.
  A call to `calculate!/1` from inside `ExportedVsInternal.Catalog.*` works. See
  `ExportedVsInternal.Catalog.InternalReports`. The same call from outside is a
  forbidden reference. See the README for that violation, reproduced for real.
  """

  use Ash.Resource,
    domain: ExportedVsInternal.Catalog,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id
    attribute :sku, :string, allow_nil?: false, public?: true
    attribute :cost, :float, allow_nil?: false, public?: true
    attribute :margin, :float, allow_nil?: false, public?: true
  end

  calculations do
    calculate :sale_price, :float, expr(cost * (1 + margin))
  end

  actions do
    defaults [:read, create: [:sku, :cost, :margin]]

    read :by_sku do
      get? true
      argument :sku, :string, allow_nil?: false
      filter expr(sku == ^arg(:sku))
      prepare build(load: [:sale_price])
    end
  end

  code_interface do
    define :record, action: :create
    define :calculate, action: :by_sku, args: [:sku]
  end
end
