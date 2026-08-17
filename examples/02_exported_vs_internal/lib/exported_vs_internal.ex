defmodule ExportedVsInternal do
  @moduledoc """
  The application's root boundary, declared with plain `use Boundary` rather than
  `AshBoundary` — this module is not an `Ash.Domain`, just this app's top namespace.

  See `examples/01_basic_boundary`'s `BasicBoundary` module for the full explanation of
  why this is mandatory: `boundary` expects every module in the app to land in *some*
  boundary, `ExportedVsInternal.Catalog` only carves out its own subtree (declared via
  `AshBoundary`), and skipping a root claim like this one does not fail loudly — it
  silently disables the forbidden-reference check for whatever is left unclassified.
  Here, that's just `ExportedVsInternal.Storefront`.
  """

  use Boundary
end
