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

    # belongs_to :author, Example.Accounts.Author is not allowed
    attribute :author_id, :uuid, allow_nil?: false, public?: true
  end

  calculations do
    calculate :byline, :string, Example.Blog.Post.Calculations.Byline do
      public? true
    end

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

      prepare build(load: [:byline, :excerpt, :word_count], sort: [title: :asc])
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
      prepare build(load: [:byline, :excerpt, :word_count])
    end
  end
end
