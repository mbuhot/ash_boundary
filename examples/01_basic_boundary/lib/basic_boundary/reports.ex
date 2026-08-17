defmodule BasicBoundary.Reports do
  @moduledoc """
  Reporting helpers for the blog domain.
  """

  alias BasicBoundary.Blog

  @doc """
  Creates a post and reads it back.
  """
  @spec create_and_fetch(String.t(), String.t()) :: BasicBoundary.Blog.Post.t()
  def create_and_fetch(title, body) do
    post = Blog.create_post!(%{title: title, body: body})
    Blog.get_post!(post.id)
  end
end
