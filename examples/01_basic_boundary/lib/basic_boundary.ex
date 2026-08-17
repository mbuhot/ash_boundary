defmodule BasicBoundary do
  @moduledoc """
  This module is the application's root boundary. It uses plain `use Boundary`,
  because it is not an `Ash.Domain`.

  `boundary` requires every module in the app to belong to some boundary. An
  unclassified module produces a separate compiler warning: "... is not
  included in any boundary". This check differs from the cross-boundary
  reference checks that `AshBoundary` performs.

  `BasicBoundary.Blog` claims its own subtree as a nested boundary, declared
  through `AshBoundary`. This root boundary claims everything else under
  `BasicBoundary.*`. Here, that is only `BasicBoundary.Reports`.

  `BasicBoundary.Reports` calls `BasicBoundary.Blog`'s exported code interface.
  This call needs no `deps` entry here: `boundary` treats a nested boundary's
  exports as available to its parent's own modules, with no explicit
  dependency declaration. Listing a descendant in `deps` explicitly is
  rejected: `boundary` reports it as not being a sibling, a parent, or a dep of
  some ancestor.

  Any app that adopts plain `boundary` needs a root boundary like this one,
  with or without `AshBoundary`. See the "Quick example" in `Boundary`'s own
  moduledoc, where plain `MySystem` plays the same role. Its absence produces a
  confusing "not included in any boundary" warning.
  """

  use Boundary
end
