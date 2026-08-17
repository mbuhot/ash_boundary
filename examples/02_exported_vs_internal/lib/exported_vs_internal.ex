defmodule ExportedVsInternal do
  @moduledoc """
  The application's root boundary. It uses plain `use Boundary`. This module is not an
  `Ash.Domain`. It is this app's top namespace.

  See `examples/01_basic_boundary`'s `BasicBoundary` module for the full explanation of
  why this declaration is mandatory. `boundary` expects every module in the app to land
  in some boundary. `ExportedVsInternal.Catalog` claims only its own subtree, declared
  through `AshBoundary`. A build with no root claim disables the forbidden-reference
  check for every unclassified module. Here, that module is
  `ExportedVsInternal.Storefront`.
  """

  use Boundary
end
