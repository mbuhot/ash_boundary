defmodule DeliberateViolation.Accounting.Summary do
  @moduledoc """
  `DeliberateViolation.Accounting`'s entire public API: a resource with no data layer and
  no attributes, holding two generic actions over the internal
  `DeliberateViolation.Accounting.LedgerEntry` resource.

  It is the only resource this domain exports (via the domain-level `define`s in
  `DeliberateViolation.Accounting`), which is the point: other domains get answers — an
  id, a running total — and never a `LedgerEntry` struct, an attribute name, or a query
  against the ledger's own storage. See `examples/03_decoupling_via_calculation`'s
  `Directory` resource for the same shape, applied there to customer data instead of
  ledger entries.
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
