defmodule DeliberateViolation.Accounting.LedgerEntry do
  @moduledoc false

  use Ash.Resource,
    domain: DeliberateViolation.Accounting,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id
    attribute :description, :string, allow_nil?: false, public?: true
    attribute :amount, :integer, allow_nil?: false, public?: true
  end

  actions do
    defaults [:read, create: [:description, :amount]]
  end

  code_interface do
    define :create
    define :read, action: :read
  end
end
