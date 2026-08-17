defmodule DeliberateViolation.Billing do
  @moduledoc """
  The domain that owns invoices, and (in its shipped, clean state) a domain that reaches
  into `DeliberateViolation.Accounting` only through what it exports.

  `boundary do deps [...] end` is the honest, reviewable admission that this domain calls
  into `DeliberateViolation.Accounting`: `DeliberateViolation.Billing.Invoice`'s
  `:ledger_total` calculation calls the exported
  `DeliberateViolation.Accounting.ledger_total!/0`. That dep buys exactly
  `Accounting`'s exports — the domain module and its `Summary` facade — and nothing
  about `Accounting.LedgerEntry`, which stays unreachable no matter what this domain
  declares.

  `violation/billing.ex` is this same domain with the same honest `deps` line, reaching
  past that boundary anyway — declaring a dependency is necessary, never sufficient. See
  the README.
  """

  use Ash.Domain, extensions: [AshBoundary]

  boundary do
    deps [DeliberateViolation.Accounting]
  end

  resources do
    resource DeliberateViolation.Billing.Invoice do
      define :issue_invoice, action: :create
      define :get_invoice, action: :read, get_by: [:id]
    end
  end
end
