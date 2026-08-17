defmodule DecouplingViaCalculation.Orders.Order do
  @moduledoc false

  use Ash.Resource,
    domain: DecouplingViaCalculation.Orders,
    data_layer: Ash.DataLayer.Ets

  alias DecouplingViaCalculation.Orders.Calculations.CustomerDisplayName

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id

    attribute :customer_id, :uuid, allow_nil?: false, public?: true

    attribute :item, :string, allow_nil?: false, public?: true
    attribute :quantity, :integer, allow_nil?: false, public?: true, default: 1
  end

  calculations do
    calculate :customer_display_name, :string, CustomerDisplayName do
      public? true
    end
  end

  actions do
    defaults [:read, create: [:customer_id, :item, :quantity]]
  end
end
