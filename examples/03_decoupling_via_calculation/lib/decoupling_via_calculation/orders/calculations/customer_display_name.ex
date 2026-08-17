defmodule DecouplingViaCalculation.Orders.Calculations.CustomerDisplayName do
  @moduledoc """
  The replacement for a cross-domain relationship, and the pattern this whole example
  exists to show: a real `Ash.Resource.Calculation` that gets its value by calling
  another domain's *exported function*, instead of reaching into that domain's resource.

  This module is the only place in `DecouplingViaCalculation.Orders` that mentions
  `DecouplingViaCalculation.Customers` at all — which is why `Orders` needs its single
  `boundary do deps [DecouplingViaCalculation.Customers] end` entry. Take this file away
  and the two domains have no compile-time relationship whatsoever.

  What crosses the boundary is a function call with a list of ids in and a map of strings
  out. What does *not* cross it:

    * `DecouplingViaCalculation.Customers.Customer` — never referenced, and not exported,
      so it could not be referenced even by accident.
    * Customer attribute names. `first_name` and `family_name` appear nowhere in
      `Orders`; renaming them is invisible here.
    * Customer's data layer, actions, filters and relationships. `Orders` issues no query
      against customer data; it asks a question and gets an answer.

  ## `calculate/3` is handed the whole batch

  Ash calls `calculate/3` once with *all* the records being loaded, which is why the
  exported interface takes a list of ids and returns a map: one order or a thousand,
  loading `:customer_display_name` makes exactly one call into
  `DecouplingViaCalculation.Customers`. Getting this wrong is the usual criticism of
  replacing a relationship with a calculation — a relationship can be joined, a naive
  calculation cannot — so it is worth being explicit that the batching lives in the
  interface, on the `Customers` side, and can be changed there without `Orders` knowing.
  """

  use Ash.Resource.Calculation

  alias DecouplingViaCalculation.Customers

  @doc """
  Ensures `customer_id` is loaded on every record before `calculate/3` runs — it is the
  only piece of the order this calculation needs.
  """
  @impl Ash.Resource.Calculation
  def load(_query, _opts, _context), do: [:customer_id]

  @doc """
  Resolves every order's customer display name in a single call across the boundary.
  """
  @impl Ash.Resource.Calculation
  def calculate(orders, _opts, _context) do
    display_names =
      orders
      |> Enum.map(& &1.customer_id)
      |> Customers.customer_display_names!()

    {:ok, Enum.map(orders, &Map.get(display_names, &1.customer_id))}
  end
end
