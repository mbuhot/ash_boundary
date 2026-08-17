defmodule Example.Blog.Post.Calculations.Excerpt do
  @moduledoc """
  Truncates a post's body to a short excerpt.
  """

  use Ash.Resource.Calculation

  @limit 40

  @impl Ash.Resource.Calculation
  def load(_query, _opts, _context), do: [:body]

  @impl Ash.Resource.Calculation
  def calculate(posts, _opts, _context) do
    {:ok, Enum.map(posts, &truncate(&1.body))}
  end

  defp truncate(body) when byte_size(body) > @limit, do: binary_part(body, 0, @limit) <> "..."
  defp truncate(body), do: body
end
