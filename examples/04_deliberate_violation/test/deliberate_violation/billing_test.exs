defmodule DeliberateViolation.BillingTest do
  @moduledoc """
  Proves the shipped, clean state works end to end, for real: a ledger entry is recorded
  through `DeliberateViolation.Accounting`'s exported interface, an invoice is issued
  through `DeliberateViolation.Billing`'s exported interface, and loading the
  `:ledger_total` calculation returns a value that came out of the *other domain's*
  ETS-backed `LedgerEntry` resource — via its exported `Summary` facade, never the
  resource itself.

  This test module sits outside both domains' namespaces, so it is restricted to exactly
  what they export — the same position any real consumer is in, and the same position
  `violation/billing/invoice.ex` and `violation/billing/ledger_entry_caller.ex` are in,
  except those reach further than this test does.
  """

  use ExUnit.Case, async: true

  alias DeliberateViolation.Accounting
  alias DeliberateViolation.Billing

  test "an invoice's ledger_total comes from Accounting's exported Summary, not from Billing" do
    entry_id = Accounting.record_entry!("Consulting", 500)

    # The invoice's own amount is deliberately NOT the ledger total. If both were 500,
    # this test could not tell a value that genuinely crossed the boundary from
    # `Billing` simply echoing back the amount it already had.
    invoice = Billing.issue_invoice!(%{ledger_entry_id: entry_id, amount: 700})

    # Billing stores only the id: there is nowhere for a total to be hiding.
    assert invoice.ledger_entry_id == entry_id
    assert invoice.amount == 700
    assert %Ash.NotLoaded{} = invoice.ledger_total

    loaded = Billing.get_invoice!(invoice.id, load: [:ledger_total])

    # 500, the ledger entry recorded through Accounting — not 700, this invoice's own
    # amount. Only the calculation calling Accounting's exported facade supplies this.
    assert loaded.ledger_total == 500
  end

  test "Accounting.total_ledger_balance!/0 sums every recorded entry, reachable only through Summary" do
    Accounting.record_entry!("Consulting", 500)
    Accounting.record_entry!("Hosting", 125)

    assert Accounting.total_ledger_balance!() == 625
  end
end
