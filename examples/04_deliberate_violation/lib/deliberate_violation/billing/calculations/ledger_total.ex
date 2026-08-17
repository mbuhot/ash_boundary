defmodule DeliberateViolation.Billing.Calculations.LedgerTotal do
  @moduledoc """
  The **contrast case**: a real `Ash.Resource.Calculation` that reaches across the
  domain boundary into `DeliberateViolation.Accounting`, exactly as
  `violation/billing/ledger_entry_caller.ex` does — except this one calls the *exported*
  `DeliberateViolation.Accounting.ledger_total!/0`, not the internal `LedgerEntry`
  resource. Same shape of cross-domain call, same `deps` declaration on `Billing`
  (see `DeliberateViolation.Billing`'s moduledoc), and it compiles clean.

  This is the module to compare against `violation/billing/ledger_entry_caller.ex` when
  reading this example's README: the only difference between "compiles clean" and
  "forbidden reference" is which module on the other side of the line got called, never
  whether a `deps` entry exists.
  """

  use Ash.Resource.Calculation

  alias DeliberateViolation.Accounting

  @impl Ash.Resource.Calculation
  def calculate(invoices, _opts, _context) do
    total = Accounting.ledger_total!()
    {:ok, Enum.map(invoices, fn _invoice -> total end)}
  end
end
