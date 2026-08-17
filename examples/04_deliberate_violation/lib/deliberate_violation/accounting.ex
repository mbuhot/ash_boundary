defmodule DeliberateViolation.Accounting do
  @moduledoc """
  The domain that owns ledger data, and the *callee* side of this example. It publishes
  exactly one thing: a purpose-built summary interface, and keeps the real ledger
  resource internal.

  Two resources, exported very differently (the distinction sample project 2 covers in
  full):

    * `DeliberateViolation.Accounting.LedgerEntry` is named by a **bare** `resource`
      entry below — no domain-level `define` — so `AshBoundary` leaves it out of
      `exports`. This is the module `DeliberateViolation.Billing` legitimately never
      touches, and the module `violation/` reaches into anyway.

    * `DeliberateViolation.Accounting.Summary` carries the domain-level `define`s, so it
      — and this domain module — are the only things this domain exports:

          DeliberateViolation.Accounting.record_entry!(description, amount)
          #=> a ledger entry id

          DeliberateViolation.Accounting.ledger_total!()
          #=> the sum of every recorded amount

  See `examples/03_decoupling_via_calculation`'s `Customers` domain for the full
  rationale behind this shape (a facade resource rather than `define`s on the internal
  resource directly) — it applies here unchanged.
  """

  use Ash.Domain, extensions: [AshBoundary]

  resources do
    # Internal: no domain-level define, so `AshBoundary` leaves it out of `exports` and
    # nothing outside `DeliberateViolation.Accounting.*` can reference it. This is the
    # module both the clean contrast case and the deliberate violation revolve around.
    resource DeliberateViolation.Accounting.LedgerEntry

    # Exported: this is the entire public API of this domain.
    resource DeliberateViolation.Accounting.Summary do
      define :record_entry, action: :record, args: [:description, :amount]
      define :ledger_total, action: :total
    end
  end
end
