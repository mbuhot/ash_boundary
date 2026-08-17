defmodule Example.Accounts.Author.Calculations.DisplayName do
  @moduledoc """
  Renders an author's name with their handle.
  """

  use Ash.Resource.Calculation

  @impl Ash.Resource.Calculation
  def load(_query, _opts, _context), do: [:name, :handle]

  @impl Ash.Resource.Calculation
  def calculate(authors, _opts, _context) do
    {:ok, Enum.map(authors, &"#{&1.name} (@#{&1.handle})")}
  end
end
