defmodule BasicBoundary.Blog.Comment do
  @moduledoc false

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
