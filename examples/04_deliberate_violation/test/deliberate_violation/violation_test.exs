defmodule DeliberateViolation.ViolationTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :timer.minutes(5)

  test "MIX_ENV=violation mix compile --warnings-as-errors fails, catching both the alias/relationship violation and the call violation" do
    {output, exit_code} =
      System.cmd("mix", ["compile", "--warnings-as-errors"],
        cd: File.cwd!(),
        env: [{"MIX_ENV", "violation"}],
        stderr_to_stdout: true
      )

    assert exit_code == 1,
           "expected `MIX_ENV=violation mix compile --warnings-as-errors` to fail " <>
             "(exit 1) because it compiles a genuine boundary violation, but it exited " <>
             "#{exit_code}. Full output:\n\n#{output}"

    assert output =~ """
           warning: forbidden reference to DeliberateViolation.Accounting.LedgerEntry
             (module DeliberateViolation.Accounting.LedgerEntry is not exported by its owner boundary DeliberateViolation.Accounting)
             violation/billing/invoice.ex:19\
           """

    assert output =~ """
           warning: forbidden reference to DeliberateViolation.Accounting.LedgerEntry
             (module DeliberateViolation.Accounting.LedgerEntry is not exported by its owner boundary DeliberateViolation.Accounting)
             violation/billing/ledger_entry_caller.ex:8\
           """
  end

  test "MIX_ENV=violation mix compile (without --warnings-as-errors) still reports both warnings but exits 0" do
    {output, exit_code} =
      System.cmd("mix", ["compile"],
        cd: File.cwd!(),
        env: [{"MIX_ENV", "violation"}],
        stderr_to_stdout: true
      )

    assert exit_code == 0,
           "boundary reports violations as warnings, not hard failures, without " <>
             "--warnings-as-errors — expected exit 0. Full output:\n\n#{output}"

    assert output =~ "forbidden reference to DeliberateViolation.Accounting.LedgerEntry"
  end
end
