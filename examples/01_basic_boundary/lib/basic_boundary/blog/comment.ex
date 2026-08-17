defmodule BasicBoundary.Blog.Comment do
  @moduledoc """
  This resource is internal. No domain-level `define` names it in
  `BasicBoundary.Blog`'s `resources` block. `AshBoundary` leaves it out of the
  domain's computed `exports`.

  No module outside `BasicBoundary.Blog.*` may reference
  `BasicBoundary.Blog.Comment`, once `mix.exs` enables the `:boundary`
  compiler. See the README for how to prove that.
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
