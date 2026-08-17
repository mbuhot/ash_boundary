defmodule BasicBoundary do
  @moduledoc """
  The application's root boundary, declared with plain `use Boundary` rather than
  `AshBoundary` — this module is not an `Ash.Domain`, just this app's top namespace.

  `boundary` classifies every module in the app by name nesting, and (by default)
  expects every module to land in *some* boundary — an unclassified module is reported
  as its own compiler warning ("... is not included in any boundary"), independent of
  the cross-boundary reference checks `AshBoundary` exists for. `BasicBoundary.Blog`
  carves its own subtree out into a nested boundary (declared via `AshBoundary`, see
  `BasicBoundary.Blog`'s moduledoc), so this root boundary is left covering everything
  else under `BasicBoundary.*` — here, just `BasicBoundary.Reports`.

  `BasicBoundary.Reports` calls into `BasicBoundary.Blog`'s exported code interface,
  but that needs no `deps` entry here: `boundary` treats `BasicBoundary.Blog` as a
  *nested* sub-boundary of this one (its name starts with `BasicBoundary.`), and a
  parent boundary's own modules are implicitly allowed to use the exports of its direct
  sub-boundaries. Listing a descendant in `deps` explicitly is in fact rejected —
  boundary reports it as not being "a sibling, a parent, or a dep of some ancestor" —
  since the access is already implicit.

  This is not an AshBoundary concern as such — any app adopting plain `boundary` needs
  a root boundary like this one for the same reason (see the "Quick example" in
  `Boundary`'s own moduledoc, where plain `MySystem` — `use Boundary, deps: [],
  exports: []`, with no `top_level?: true` — plays this role for the rest of its own
  namespace; `MySystem.Application` there is a different case, promoted with
  `top_level?: true` into a sibling of `MySystem` precisely so it can declare deps on
  more than one boundary at once, which a plain nested claim like this one could not).
  This module is included here because a real consuming app will need one too, and its
  absence is exactly the kind of thing that produces a confusing warning with no
  obvious cause.
  """

  use Boundary
end
