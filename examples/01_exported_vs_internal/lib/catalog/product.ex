defmodule Catalog.Product do
  @moduledoc false

  use Ash.Resource,
    domain: Catalog,
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
