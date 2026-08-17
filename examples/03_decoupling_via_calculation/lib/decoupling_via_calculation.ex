defmodule DecouplingViaCalculation do
  @moduledoc """
  This module is the application's root boundary.
  It uses plain `use Boundary`. It does not use `AshBoundary`.
  This module is not an `Ash.Domain`. It is the app's top namespace.

  See `examples/01_basic_boundary`'s `BasicBoundary` module for the full explanation.
  Every module in the app must land in some boundary.
  `DecouplingViaCalculation.Customers` and `DecouplingViaCalculation.Orders` carve
  out only their own subtrees.
  A missing root claim silently disables the forbidden-reference check for any
  unclassified module. It gives no warning.

  This boundary needs no `deps`.
  `Customers` and `Orders` are nested sub-boundaries of this one.
  A parent boundary may use its direct sub-boundaries' exports implicitly.
  The dependency that matters in this example runs between two siblings: `Orders`
  on `Customers`. A sibling dependency is never implicit. It must be declared.
  See `DecouplingViaCalculation.Orders`.
  """

  use Boundary
end
