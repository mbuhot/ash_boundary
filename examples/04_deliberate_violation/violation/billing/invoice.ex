defmodule DeliberateViolation.Violation.Billing.Invoice do
  @moduledoc """
  **DELIBERATE VIOLATION — not compiled by any normal build. See `mix.exs` and the
  README.**

  Identical to the shipped `DeliberateViolation.Billing.Invoice`, except
  `ledger_entry_id` — a plain attribute there — is a `belongs_to` relationship here,
  pointed directly at `DeliberateViolation.Accounting.LedgerEntry`.

  This is the **alias-style** violation: a relationship names a module and calls nothing
  on it, which is exactly the kind of reference `boundary` does not check by default
  (`check: [aliases: false]` is its documented default). AshBoundary turns alias
  checking on for every domain it declares, which is the only reason this line is
  caught at all — see this example's README, and
  `examples/03_decoupling_via_calculation`'s "Alias checking is on by default" section
  for the same point made in full.
  """

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
    # The alias-style violation. `LedgerEntry` is not exported by
    # `DeliberateViolation.Accounting`, and a declared `deps` entry does not reach past
    # another boundary's exports.
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
