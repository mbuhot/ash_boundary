defmodule DecouplingViaCalculation.Antipattern.Customers.Customer do
  @moduledoc false

  use Ash.Resource,
    domain: DecouplingViaCalculation.Antipattern.Customers,
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
  end
end
