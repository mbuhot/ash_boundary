defmodule BasicBoundary.ReportsTest do
  @moduledoc """
  Lives outside `BasicBoundary.Blog`'s namespace, same as the module under test — this
  is what "the happy path actually works" means for this example: a real module,
  outside the domain, genuinely calling the domain's exported code interface, run for
  real by `mix test`.

  This is also this example's whole enforcement proof for the *exported* side of the
  library: nothing here is boundary-specific (there is no API to assert "no violation
  was raised" against — a violation is a compiler diagnostic, not a runtime exception),
  so passing this test simply is the proof that exporting `Post` via a domain-level
  `define` does not get in this call's way. The other half — that reaching
  `BasicBoundary.Blog.Comment` from here instead would be *rejected* — can only be
  observed by the `:boundary` compiler, which only runs on `mix compile`, not `mix
  test`; see the README for how to reproduce that half yourself.
  """

  use ExUnit.Case, async: true

  alias BasicBoundary.Reports

  test "creating and fetching a post through the domain's exported interface works" do
    post = Reports.create_and_fetch("Hello", "World")

    assert post.title == "Hello"
    assert post.body == "World"
  end
end
