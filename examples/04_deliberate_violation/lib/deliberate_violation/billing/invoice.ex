defmodule DeliberateViolation.Billing.Invoice do
  @moduledoc """
  An invoice, exported by `DeliberateViolation.Billing` via its domain-level `define`s.

  It holds `ledger_entry_id`, a plain `:uuid` attribute — not a relationship — recording
  which ledger entry it is associated with. It has no reference to
  `DeliberateViolation.Accounting.LedgerEntry`, the module, at all: compare this to
  `violation/billing/invoice.ex`, which is this same resource with one field changed to
  a `belongs_to`, and does not compile.

  The `:ledger_total` calculation is the clean half of this example's side-by-side: it
  reaches into `DeliberateViolation.Accounting` through
  `DeliberateViolation.Billing.Calculations.LedgerTotal`, which calls the domain's
  *exported* `ledger_total!/0` — see that module's moduledoc for the direct comparison
  with the deliberate violation.
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
