defmodule DeliberateViolation.Violation.Billing.Invoice do
  @moduledoc """
  **DELIBERATE VIOLATION. No normal build compiles this file. See `mix.exs`
  and the README.**

  This resource is identical to the shipped `DeliberateViolation.Billing.Invoice`.
  `ledger_entry_id` is a plain attribute there. Here it is a `belongs_to`
  relationship, pointed directly at `DeliberateViolation.Accounting.LedgerEntry`.

  This is the alias-style violation. A relationship names a module and calls nothing
  on it. `boundary` does not check this kind of reference by default: its documented
  default is `check: [aliases: false]`. AshBoundary turns alias checking on for every
  domain it declares. This is the only reason this line is caught at all. See this
  example's README, and the "Alias checking is on by default" section in
  `examples/03_decoupling_via_calculation` for the same point made in full.
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
