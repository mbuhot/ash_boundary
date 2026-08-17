defmodule DeliberateViolation.Violation.Billing.LedgerEntryCaller do
  @moduledoc """
  **DELIBERATE VIOLATION. No normal build compiles this file. See `mix.exs`
  and the README.**

  This is the call-style violation, the counterpart to `invoice.ex`'s alias-style
  one. This module makes a plain function call, `Module.function()`, from outside
  `DeliberateViolation.Accounting`'s namespace straight at its internal
  `LedgerEntry.create!/1`. `LedgerEntry`'s own `code_interface` generates this
  function (see sample project 2). The function is real and callable. It is still
  forbidden from here, because `boundary` only ever asks whether the module is
  exported. It never asks how the called function came to exist.
  """

  alias DeliberateViolation.Accounting.LedgerEntry

  def run do
    LedgerEntry.create!(%{description: "Reached in directly", amount: 0})
  end
end
