defmodule DeliberateViolation.Billing.Calculations.LedgerTotal do
  @moduledoc """
  This module is the contrast case: a real `Ash.Resource.Calculation` that reaches
  across the domain boundary into `DeliberateViolation.Accounting`.
  `violation/billing/ledger_entry_caller.ex` reaches across the same boundary. This
  module calls the exported `DeliberateViolation.Accounting.ledger_total!/0`. It never
  calls the internal `LedgerEntry` resource. Both calls share the same shape and the
  same `deps` declaration on `DeliberateViolation.Billing` (see that module's
  moduledoc). This module compiles clean.

  Compare this module to `violation/billing/ledger_entry_caller.ex` when reading this
  example's README. The only difference between a clean compile and a forbidden
  reference is which module on the other side of the line received the call. A `deps`
  entry alone never decides the outcome.
  """

  use Ash.Resource.Calculation

  alias DeliberateViolation.Accounting

  @impl Ash.Resource.Calculation
  def calculate(invoices, _opts, _context) do
    total = Accounting.ledger_total!()
    {:ok, Enum.map(invoices, fn _invoice -> total end)}
  end
end
