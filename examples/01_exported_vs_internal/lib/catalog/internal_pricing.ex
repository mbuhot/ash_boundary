defmodule Catalog.InternalPricing do
  @moduledoc false

  use Ash.Resource,
    domain: Catalog,
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
