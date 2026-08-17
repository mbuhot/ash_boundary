defmodule DeliberateViolation.Billing.Invoice do
  @moduledoc """
  `DeliberateViolation.Billing` exports this invoice through its domain-level
  `define`s.

  It holds `ledger_entry_id`, a plain `:uuid` attribute. This attribute records which
  ledger entry the invoice is associated with. It is not a relationship. This resource
  has no reference to the `DeliberateViolation.Accounting.LedgerEntry` module at all.
  Compare this resource to `violation/billing/invoice.ex`. That resource changes one
  field to a `belongs_to` relationship, and it does not compile.

  The `:ledger_total` calculation is the clean half of this example's side-by-side
  comparison. It reaches into `DeliberateViolation.Accounting` through
  `DeliberateViolation.Billing.Calculations.LedgerTotal`, which calls the domain's
  exported `total_ledger_balance!/0`. See that module's moduledoc for the direct
  comparison with the deliberate violation, and for why the calculation returns the
  same whole-ledger figure for every invoice rather than a per-invoice amount.
  """

  use Ash.Resource,
    domain: DeliberateViolation.Billing,
    data_layer: Ash.DataLayer.Ets

  alias DeliberateViolation.Billing.Calculations.LedgerTotal

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id

    # Just an id. Deliberately not a `belongs_to` to another domain's resource — see
    # `violation/billing/invoice.ex` for what that would look like, and why it doesn't
    # compile.
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
