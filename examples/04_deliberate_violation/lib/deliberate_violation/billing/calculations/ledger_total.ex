defmodule DeliberateViolation.Billing.Calculations.LedgerTotal do
  @moduledoc false

  use Ash.Resource.Calculation

  alias DeliberateViolation.Accounting

  @impl Ash.Resource.Calculation
  def calculate(invoices, _opts, _context) do
    total = Accounting.total_ledger_balance!()
    {:ok, Enum.map(invoices, fn _invoice -> total end)}
  end
end
