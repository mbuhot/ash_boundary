defmodule DecouplingViaCalculation.Orders.Calculations.CustomerDisplayName do
  @moduledoc false

  use Ash.Resource.Calculation

  alias DecouplingViaCalculation.Customers

  @impl Ash.Resource.Calculation
  def load(_query, _opts, _context), do: [:customer_id]

  @impl Ash.Resource.Calculation
  def calculate(orders, _opts, _context) do
    display_names =
      orders
      |> Enum.map(& &1.customer_id)
      |> Customers.customer_display_names!()

    {:ok, Enum.map(orders, &Map.get(display_names, &1.customer_id))}
  end
end
