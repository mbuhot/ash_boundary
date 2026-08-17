defmodule Example.Blog do
  @moduledoc """
  The blog domain.
  """

  use Ash.Domain, extensions: [AshBoundary, AshPhoenix]

  boundary do
    deps [Example.Accounts]
  end

  resources do
    resource Example.Blog.Post do
      define :list_published_posts, action: :list_published
      define :get_post_by_id, action: :by_id, args: [:id]
      define :create_post, action: :create
      define :list_posts, action: :read
      define :delete_post, action: :destroy
    end
  end
end
