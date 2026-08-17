defmodule DeliberateViolation.Violation.Billing do
  @moduledoc """
  **DELIBERATE VIOLATION. No normal build compiles this file. See `mix.exs`
  and the README.**

  This module is `DeliberateViolation.Billing`, with the same honest dependency
  declaration. It reaches past that boundary anyway. This domain declares its
  cross-domain dependency correctly, in exactly the reviewable line `AshBoundary` asks
  for:

      boundary do
        deps [DeliberateViolation.Accounting]
      end

  Declaring the dep is necessary. It grants access only to what
  `DeliberateViolation.Accounting` exports: the domain module and the `Summary`
  facade. `DeliberateViolation.Violation.Billing.Invoice` (a relationship) and
  `DeliberateViolation.Violation.Billing.LedgerEntryCaller` (a function call) both
  reach past that grant, straight at the internal `LedgerEntry` resource. That is the
  violation, twice over. No `deps` entry makes either instance of it legal.
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
