defmodule DecouplingViaCalculation.Customers.Directory do
  @moduledoc """
  This resource is the `DecouplingViaCalculation.Customers` domain's entire
  public API. It has no data layer and no attributes. It holds two generic
  actions over the internal `DecouplingViaCalculation.Customers.Customer`
  resource.

  This domain exports only this resource, through the domain-level `define`s
  in `DecouplingViaCalculation.Customers`. The exported surface equals the
  interface. Other domains get answers: an id, a map of display names. They
  never get a `Customer` struct, an attribute name, or a query.

  Both actions match what the caller needs:

    * `:register` returns the new customer's id. It does not return the
      record. No other domain ever holds a `Customer` struct.

    * `:display_names` takes a list of ids and returns a map. The caller is an
      `Ash.Resource.Calculation`. Its `calculate/3` callback receives every
      record in the batch at once (see
      `DecouplingViaCalculation.Orders.Calculations.CustomerDisplayName`). A
      one-id-at-a-time interface would turn one query into one query per
      order. `Customers` makes this batching decision on its own side of the
      boundary. Changing the strategy changes nothing in `Orders`.
  """

  use Ash.Resource, domain: DecouplingViaCalculation.Customers

  alias DecouplingViaCalculation.Customers.Customer

  actions do
    action :register, :uuid do
      description "Registers a customer and returns only its id."

      argument :first_name, :string, allow_nil?: false
      argument :family_name, :string, allow_nil?: false

      run fn input, _context ->
        customer =
          Customer.create!(%{
            first_name: input.arguments.first_name,
            family_name: input.arguments.family_name
          })

        {:ok, customer.id}
      end
    end

    action :display_names, :map do
      description "Maps each of the given customer ids to that customer's display name."

      argument :ids, {:array, :uuid}, allow_nil?: false

      run fn input, _context ->
        names =
          input.arguments.ids
          |> Enum.uniq()
          |> Customer.by_ids!()
          |> Map.new(&{&1.id, &1.display_name})

        {:ok, names}
      end
    end
  end
end
