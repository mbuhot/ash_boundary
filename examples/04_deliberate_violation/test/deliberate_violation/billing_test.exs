defmodule DeliberateViolation.BillingTest do
  use ExUnit.Case, async: true

  alias DeliberateViolation.Accounting
  alias DeliberateViolation.Billing

  test "an invoice's ledger_total comes from Accounting's exported Summary, not from Billing" do
    entry_id = Accounting.record_entry!("Consulting", 500)

    invoice = Billing.issue_invoice!(%{ledger_entry_id: entry_id, amount: 700})

    assert invoice.ledger_entry_id == entry_id
    assert invoice.amount == 700
    assert %Ash.NotLoaded{} = invoice.ledger_total

    loaded = Billing.get_invoice!(invoice.id, load: [:ledger_total])

    assert loaded.ledger_total == 500
  end

  test "Accounting.total_ledger_balance!/0 sums every recorded entry, reachable only through Summary" do
    Accounting.record_entry!("Consulting", 500)
    Accounting.record_entry!("Hosting", 125)

    assert Accounting.total_ledger_balance!() == 625
  end
end
