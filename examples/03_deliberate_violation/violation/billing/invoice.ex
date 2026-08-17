defmodule DeliberateViolation.Violation.Billing.Invoice do
  @moduledoc false

  use Ash.Resource,
    domain: DeliberateViolation.Violation.Billing,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id
    attribute :amount, :integer, allow_nil?: false, public?: true
  end

  relationships do
    # This is the violation:
    belongs_to :ledger_entry, DeliberateViolation.Accounting.LedgerEntry do
      allow_nil? false
      attribute_writable? true
      public? true
    end
  end

  actions do
    defaults [:read, create: [:amount, :ledger_entry_id]]
  end
end
