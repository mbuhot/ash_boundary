defmodule BasicBoundary.Blog.Post do
  @moduledoc """
  Exported: has a domain-level `define` in `BasicBoundary.Blog`'s `resources` block, so
  `AshBoundary` includes it in the domain's computed `exports`. Code outside
  `BasicBoundary.Blog.*` may reference this module directly (as
  `BasicBoundary.Reports` does), or go through the domain's code interface
  (`BasicBoundary.Blog.create_post!/1`, `BasicBoundary.Blog.get_post!/1`).
  """

  use Ash.Resource,
    domain: BasicBoundary.Blog,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :body, :string, public?: true
  end

  actions do
    defaults [:read, create: [:title, :body]]
  end
end
