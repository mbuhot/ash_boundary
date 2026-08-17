defmodule DecouplingViaCalculation.Orders.Calculations.CustomerDisplayName do
  @moduledoc """
  This module replaces a cross-domain relationship. It shows the pattern this
  whole example teaches: a real `Ash.Resource.Calculation` gets its value by
  calling another domain's exported function.

  This module is the only place in `DecouplingViaCalculation.Orders` that
  mentions `DecouplingViaCalculation.Customers`. This is why `Orders` needs
  its single `boundary do deps [DecouplingViaCalculation.Customers] end`
  entry. Remove this file and the two domains keep no compile-time
  relationship.

  What crosses the boundary is one function call: a list of ids in, a map of
  strings out. These things do not cross it:

    * `DecouplingViaCalculation.Customers.Customer`. This module never
      references it. `Customers` does not export it, so no code can reference
      it by accident.
    * Customer attribute names. `first_name` and `family_name` appear nowhere
      in `Orders`. Renaming them stays invisible here.
    * Customer's data layer, actions, filters, and relationships. `Orders`
      issues no query against customer data. It asks a question and gets an
      answer.

  ## `calculate/3` receives the whole batch

  Ash calls `calculate/3` once with all the records being loaded. This is why
  the exported interface takes a list of ids and returns a map. Loading
  `:customer_display_name` makes exactly one call into
  `DecouplingViaCalculation.Customers`, for one order or a thousand orders.
  A relationship can be joined. A naive calculation cannot join. This is a
  common objection to replacing a relationship with a calculation. The
  batching logic lives in the interface, on the `Customers` side. It can
  change there without `Orders` knowing.
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
