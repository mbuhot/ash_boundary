defmodule Example.Post do
  @moduledoc false

  use Ash.Resource,
    domain: Example,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(false)
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string, allow_nil?: false, public?: true
    attribute :body, :string, allow_nil?: false, public?: true
    attribute :author, :string, allow_nil?: false, public?: true
    attribute :published?, :boolean, allow_nil?: false, public?: true, default: true
  end

  calculations do
    calculate :excerpt, :string, Example.Post.Calculations.Excerpt do
      public? true
    end

    calculate :word_count, :integer, expr(length(string_split(body))) do
      public? true
    end
  end

  actions do
    defaults [:read, :destroy, create: [:title, :body, :author, :published?]]

    read :list_published do
      filter expr(published? == true)

      prepare build(load: [:excerpt, :word_count], sort: [title: :asc])
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
      prepare build(load: [:excerpt, :word_count])
    end

    update :moderate do
      accept [:published?]
    end
  end
end
