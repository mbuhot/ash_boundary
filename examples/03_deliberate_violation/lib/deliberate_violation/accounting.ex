defmodule DeliberateViolation.Accounting do
  @moduledoc """
  The accounting domain.
  """

  use Ash.Domain, extensions: [AshBoundary]

  resources do
    resource DeliberateViolation.Accounting.LedgerEntry

    resource DeliberateViolation.Accounting.Summary do
      define :record_entry, action: :record, args: [:description, :amount]
      define :total_ledger_balance, action: :total
    end
  end
end
