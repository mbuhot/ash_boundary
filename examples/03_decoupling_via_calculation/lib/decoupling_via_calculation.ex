defmodule DecouplingViaCalculation do
  @moduledoc """
  The application's root boundary, declared with plain `use Boundary` rather than
  `AshBoundary` — this module is not an `Ash.Domain`, just this app's top namespace.

  See `examples/01_basic_boundary`'s `BasicBoundary` module for the full explanation of
  why this is mandatory: `boundary` expects every module in the app to land in *some*
  boundary, `DecouplingViaCalculation.Customers` and `DecouplingViaCalculation.Orders`
  only carve out their own subtrees, and skipping a root claim like this one does not
  fail loudly — it silently disables the forbidden-reference check for whatever is left
  unclassified.

  No `deps` are needed here even though this boundary owns nothing that calls into the
  two domains: they are *nested* sub-boundaries of this one, and a parent boundary may
  use its direct sub-boundaries' exports implicitly. The dependency that matters in this
  example is between two *siblings* — `Orders` on `Customers` — which is never implicit
  and has to be declared, see `DecouplingViaCalculation.Orders`.
  """

  use Boundary
end
