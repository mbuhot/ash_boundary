defmodule Example.Blog.Post do
  @moduledoc false

  use Ash.Resource,
    domain: Example.Blog,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(false)
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string, allow_nil?: false, public?: true
    attribute :body, :string, allow_nil?: false, public?: true
    attribute :published?, :boolean, allow_nil?: false, public?: true, default: true
  end

  relationships do
    belongs_to :author, Example.Accounts.Author do
      domain Example.Accounts
      allow_nil? false
      attribute_public? true
      attribute_writable? true
      public? true
    end
  end

  calculations do
    # Example.Accounts exports Author, not the calculation module behind display_name.
    # calculate :byline, :string, Example.Accounts.Author.Calculations.DisplayName
    calculate :excerpt, :string, Example.Blog.Post.Calculations.Excerpt do
      public? true
    end

    calculate :word_count, :integer, expr(length(string_split(body))) do
      public? true
    end
  end

  actions do
    defaults [:read, :destroy, create: [:title, :body, :author_id, :published?]]

    read :list_published do
      filter expr(published? == true)

      prepare build(
                load: [:excerpt, :word_count, author: [:display_name]],
                sort: [title: :asc]
              )
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
      prepare build(load: [:excerpt, :word_count, author: [:display_name]])
    end
  end
end
