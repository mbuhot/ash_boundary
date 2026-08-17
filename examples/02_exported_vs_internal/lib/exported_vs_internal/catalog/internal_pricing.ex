defmodule ExportedVsInternal.Catalog.InternalPricing do
  @moduledoc """
  Internal: `ExportedVsInternal.Catalog`'s `resources` block names this resource with a
  bare `resource` entry — no domain-level `define` — so `AshBoundary` leaves it out of
  the domain's computed `exports`. That is the *only* thing that determines exported
  status; it has nothing to do with whether the resource itself has a code interface.

  And this resource does have one: the `code_interface` block below defines
  `record/1` (wraps the `:create` action) and `calculate/1` (wraps the `:by_sku` read
  action, including the `sale_price` calculation). Both are ordinary generated
  functions on this module, exactly as real and callable as `Product`'s. `boundary`
  does not distinguish "a code interface function" from any other function on a
  module — it only ever asks "is the *module* exported by its owner boundary?" — so
  calling `calculate!/1` from *inside* `ExportedVsInternal.Catalog.*` (see
  `ExportedVsInternal.Catalog.InternalReports`) works fine, while the exact same call
  from outside is a forbidden reference. See the README for that second half,
  reproduced for real.
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
