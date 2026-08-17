defmodule BasicBoundary.Reports do
  @moduledoc """
  Lives outside `BasicBoundary.Blog`'s namespace entirely, and calls into it only
  through the domain's exported code interface — the happy path `AshBoundary`
  is meant to leave completely unaffected.

  Compare `test/basic_boundary/reports_test.exs`, which runs this for real (creates a
  post through `BasicBoundary.Blog.create_post!/1` and reads it back through
  `BasicBoundary.Blog.get_post!/1`), rather than merely asserting the module compiles.
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
