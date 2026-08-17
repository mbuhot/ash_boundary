defmodule DeliberateViolation.Billing do
  @moduledoc """
  This domain owns invoices. In its shipped, clean state, it reaches into
  `DeliberateViolation.Accounting` only through what that domain exports.

  `boundary do deps [...] end` is the honest, reviewable declaration that this domain
  calls into `DeliberateViolation.Accounting`. `DeliberateViolation.Billing.Invoice`'s
  `:ledger_total` calculation calls the exported
  `DeliberateViolation.Accounting.ledger_total!/0`. That `deps` entry grants access to
  `Accounting`'s exports: the domain module and the `Summary` facade. It grants no
  access to `Accounting.LedgerEntry`, which stays unreachable no matter what this
  domain declares.

  `violation/billing.ex` is this same domain with the same honest `deps` line. It
  reaches past that boundary anyway. Declaring a dependency is necessary. It is never
  sufficient on its own. See the README.
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
