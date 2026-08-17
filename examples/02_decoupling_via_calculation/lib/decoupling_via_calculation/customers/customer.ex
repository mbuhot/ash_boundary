defmodule DecouplingViaCalculation.Customers.Customer do
  @moduledoc false

  use Ash.Resource,
    domain: DecouplingViaCalculation.Customers,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id
    attribute :first_name, :string, allow_nil?: false, public?: true
    attribute :family_name, :string, allow_nil?: false, public?: true
  end

  calculations do
    calculate :display_name, :string, expr(string_join([first_name, family_name], " "))
  end

  actions do
    defaults [:read, create: [:first_name, :family_name]]

    read :by_ids do
      argument :ids, {:array, :uuid}, allow_nil?: false
      filter expr(id in ^arg(:ids))
      prepare build(load: [:display_name])
    end
  end

  code_interface do
    define :create
    define :by_ids, action: :by_ids, args: [:ids]
  end
end
