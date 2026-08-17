defmodule DeliberateViolation.Violation.Billing do
  @moduledoc """
  **DELIBERATE VIOLATION — not compiled by any normal build. See `mix.exs` and the
  README.**

  This is `DeliberateViolation.Billing`, with the same honest dependency declaration,
  reaching past it anyway. Note what this domain does *right*: it declares the
  cross-domain dependency it has, in exactly the reviewable line `AshBoundary` asks for.

      boundary do
        deps [DeliberateViolation.Accounting]
      end

  Declaring the dep is necessary and not sufficient. It grants access to what
  `DeliberateViolation.Accounting` *exports* — the domain module and its `Summary`
  facade — and both `DeliberateViolation.Violation.Billing.Invoice` (a relationship) and
  `DeliberateViolation.Violation.Billing.LedgerEntryCaller` (a function call) reach past
  that, straight at the internal `LedgerEntry` resource. That is the violation, twice
  over, and no `deps` entry makes either instance of it legal.
  """

  use Ash.Domain, extensions: [AshBoundary]

  boundary do
    deps [DeliberateViolation.Accounting]
  end

  resources do
    resource DeliberateViolation.Violation.Billing.Invoice do
      define :issue_invoice, action: :create
      define :get_invoice, action: :read, get_by: [:id]
    end
  end
end
