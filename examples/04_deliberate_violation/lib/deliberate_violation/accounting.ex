defmodule DeliberateViolation.Accounting do
  @moduledoc """
  This domain owns ledger data. It is the callee side of this example.

  It exports one thing: a purpose-built summary interface. It keeps the real ledger
  resource internal.

  This domain holds two resources. AshBoundary exports them very differently, a
  distinction sample project 2 covers in full:

    * `DeliberateViolation.Accounting.LedgerEntry` has a bare `resource` entry below,
      with no domain-level `define`. AshBoundary leaves this module out of `exports`.
      `DeliberateViolation.Billing` never touches this module legitimately.
      `violation/` reaches into this module anyway.

    * `DeliberateViolation.Accounting.Summary` carries the domain-level `define`s.
      This domain exports only `Summary` and the domain module itself:

          DeliberateViolation.Accounting.record_entry!(description, amount)
          #=> a ledger entry id

          DeliberateViolation.Accounting.ledger_total!()
          #=> the sum of every recorded amount

  See the `Customers` domain in `examples/03_decoupling_via_calculation` for the full
  rationale behind this shape. That example uses a facade resource instead of `define`s
  on the internal resource directly. The same rationale applies here unchanged.
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
