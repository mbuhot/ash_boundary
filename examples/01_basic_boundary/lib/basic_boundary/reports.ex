defmodule BasicBoundary.Reports do
  @moduledoc """
  This module lives outside `BasicBoundary.Blog`'s namespace. It calls into
  the domain only through its exported code interface. This is the happy path
  `AshBoundary` leaves unaffected.

  `test/basic_boundary/reports_test.exs` runs this code. It creates a post
  through `BasicBoundary.Blog.create_post!/1` and reads it back through
  `BasicBoundary.Blog.get_post!/1`.
  """

  alias BasicBoundary.Blog

  @doc """
  Creates a post and immediately reads it back, entirely through
  `BasicBoundary.Blog`'s domain-level code interface.
  """
  @spec create_and_fetch(String.t(), String.t()) :: BasicBoundary.Blog.Post.t()
  def create_and_fetch(title, body) do
    post = Blog.create_post!(%{title: title, body: body})
    Blog.get_post!(post.id)
  end
end
