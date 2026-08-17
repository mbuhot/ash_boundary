defmodule BasicBoundary.Blog do
  @moduledoc """
  The blog domain.
  """

  use Ash.Domain, extensions: [AshBoundary]

  resources do
    resource BasicBoundary.Blog.Post do
      define :create_post, action: :create
      define :get_post, action: :read, get_by: [:id]
    end

    resource BasicBoundary.Blog.Comment
  end
end
