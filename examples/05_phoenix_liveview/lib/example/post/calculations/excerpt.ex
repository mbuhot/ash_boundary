defmodule Example.Post.Calculations.Excerpt do
  @moduledoc """
  Truncates a post's body to a short excerpt.

  This is a module calculation, not an `expr/1` one. Ash's expression language has no substring
  function. `Ash.Query.Function` offers `string_length/1`, `string_split/1`, `string_join/2`, and
  similar functions, but it offers no function that slices a binary. A data-layer `fragment/1`
  would be worse than four obvious lines of Elixir. The `:word_count` calculation beside it does
  use `expr/1`, so the resource shows both styles.

  This module lives inside the `Example` boundary. It can therefore use
  `Ash.Resource.Calculation` and reference the `:ash` application freely, unlike any module under
  `ExampleWeb`. That asymmetry is the design. The restriction applies to the web layer only, and
  the domain stays an ordinary Ash citizen.
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
