defmodule DeliberateViolation.Billing.Invoice do
  @moduledoc false

  use Ash.Resource,
    domain: DeliberateViolation.Billing,
    data_layer: Ash.DataLayer.Ets

  alias DeliberateViolation.Billing.Calculations.LedgerTotal

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id

    attribute :ledger_entry_id, :uuid, allow_nil?: false, public?: true

    attribute :amount, :integer, allow_nil?: false, public?: true
  end

  calculations do
    calculate :ledger_total, :integer, LedgerTotal do
      public? true
    end
  end

  actions do
    defaults [:read, create: [:ledger_entry_id, :amount]]
  end
end
