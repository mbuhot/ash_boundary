defmodule DeliberateViolation do
  @moduledoc """
  This is the app's root boundary. It uses plain `use Boundary`, not `AshBoundary`.
  This module is not an `Ash.Domain`. It is the app's top namespace.

  See the `BasicBoundary` module in examples/01_basic_boundary for the full explanation.
  The `boundary` library requires every module in the app to belong to a boundary.
  `DeliberateViolation.Accounting` and `DeliberateViolation.Billing` cover only their own subtrees.
  A missing root boundary disables the forbidden-reference check for every unclassified module, and does so silently.

  This module matters most in this example. The example exists to show a caught violation.
  A missing root boundary would let that violation pass unproven.
  """

  use Boundary
end
