defmodule DeliberateViolation.Accounting.Summary do
  @moduledoc """
  The accounting domain's public interface.
  """

  use Ash.Resource, domain: DeliberateViolation.Accounting

  alias DeliberateViolation.Accounting.LedgerEntry

  actions do
    action :record, :uuid do
      description "Records a ledger entry and returns only its id."

      argument :description, :string, allow_nil?: false
      argument :amount, :integer, allow_nil?: false

      run fn input, _context ->
        entry =
          LedgerEntry.create!(%{
            description: input.arguments.description,
            amount: input.arguments.amount
          })

        {:ok, entry.id}
      end
    end

    action :total, :integer do
      description "Sums the amount of every recorded ledger entry."

      run fn _input, _context ->
        total =
          LedgerEntry.read!()
          |> Enum.map(& &1.amount)
          |> Enum.sum()

        {:ok, total}
      end
    end
  end
end
