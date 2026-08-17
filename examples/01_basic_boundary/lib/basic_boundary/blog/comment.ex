defmodule BasicBoundary.Blog.Comment do
  @moduledoc """
  Internal: no domain-level `define` names this resource in `BasicBoundary.Blog`'s
  `resources` block (the default when a `resource` entry has no nested `define`
  calls), so `AshBoundary` leaves it out of the domain's computed `exports`.

  Nothing outside `BasicBoundary.Blog.*` may reference `BasicBoundary.Blog.Comment`
  once `mix.exs` enables the `:boundary` compiler — see the README for how to prove
  that by attempting it deliberately.
  """

  use Ash.Resource,
    domain: BasicBoundary.Blog,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id
    attribute :body, :string, allow_nil?: false, public?: true
  end

  actions do
    defaults [:read, create: [:body]]
  end
end
