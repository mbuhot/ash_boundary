defmodule DeliberateViolation do
  @moduledoc """
  The application's root boundary, declared with plain `use Boundary` rather than
  `AshBoundary` — this module is not an `Ash.Domain`, just this app's top namespace.

  See `examples/01_basic_boundary`'s `BasicBoundary` module for the full explanation of
  why this is mandatory: `boundary` expects every module in the app to land in *some*
  boundary, `DeliberateViolation.Accounting` and `DeliberateViolation.Billing` only carve
  out their own subtrees, and skipping a root claim like this one does not fail loudly —
  it silently disables the forbidden-reference check for whatever is left unclassified.

  This is the single most important line in this example, more so than in 01–03: sample
  project 4's entire reason to exist is a caught violation, and a missing root boundary
  here would mean the violation demonstrated below silently proves nothing.
  """

  use Boundary
end
