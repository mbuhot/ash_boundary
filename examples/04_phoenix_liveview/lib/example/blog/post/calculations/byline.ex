defmodule Example.Blog.Post.Calculations.Byline do
  @moduledoc """
  Names a post's author, through the accounts domain's exported interface.
  """

  use Ash.Resource.Calculation

  @impl Ash.Resource.Calculation
  def load(_query, _opts, _context), do: [:author_id]

  @impl Ash.Resource.Calculation
  def calculate(posts, _opts, _context) do
    # Reading Example.Accounts.Author is not allowed
    # bylines = Map.new(Ash.read!(Example.Accounts.Author), &{&1.id, &1.display_name})
    bylines = Example.Accounts.author_bylines!(Enum.map(posts, & &1.author_id))

    {:ok, Enum.map(posts, &Map.get(bylines, &1.author_id, "unknown author"))}
  end
end
