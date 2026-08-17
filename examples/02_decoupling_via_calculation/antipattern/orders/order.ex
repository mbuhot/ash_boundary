defmodule DecouplingViaCalculation.Antipattern.Orders.Order do
  @moduledoc false

  use Ash.Resource,
    domain: DecouplingViaCalculation.Antipattern.Orders,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id
    attribute :item, :string, allow_nil?: false, public?: true
    attribute :quantity, :integer, allow_nil?: false, public?: true, default: 1
  end

  relationships do
    # This is the violation:
    belongs_to :customer, DecouplingViaCalculation.Antipattern.Customers.Customer do
      allow_nil? false
      attribute_writable? true
      public? true
    end
  end

  actions do
    defaults [:read, create: [:item, :quantity, :customer_id]]

    read :with_customer do
      prepare build(load: [:customer])
    end
  end
end
