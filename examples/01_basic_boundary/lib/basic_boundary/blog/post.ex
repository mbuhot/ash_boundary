defmodule BasicBoundary.Blog.Post do
  @moduledoc false

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
