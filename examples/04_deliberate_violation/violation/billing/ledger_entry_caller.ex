defmodule DeliberateViolation.Violation.Billing.LedgerEntryCaller do
  @moduledoc false

  alias DeliberateViolation.Accounting.LedgerEntry

  def run do
    # This is the violation:
    LedgerEntry.create!(%{description: "Reached in directly", amount: 0})
  end
end
