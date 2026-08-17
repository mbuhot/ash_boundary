defmodule DecouplingViaCalculation.Customers.Directory do
  @moduledoc """
  The `DecouplingViaCalculation.Customers` domain's entire public API: a resource with no
  data layer and no attributes, holding two generic actions over the internal
  `DecouplingViaCalculation.Customers.Customer` resource.

  It is the only resource this domain exports (via the domain-level `define`s in
  `DecouplingViaCalculation.Customers`), which is the point: the exported surface is
  exactly the interface, and no wider. Other domains get answers — an id, a map of
  display names — and never a `Customer` struct, an attribute name, or a query.

  Both actions are deliberately shaped around what the *caller* needs rather than around
  the table:

    * `:register` returns the new customer's **id**, not the record, so no other domain
      ever holds a `Customer` struct.

    * `:display_names` takes a **list** of ids and returns a map. That shape exists
      because the caller is an `Ash.Resource.Calculation`, whose `calculate/3` callback is
      handed every record in the batch at once (see
      `DecouplingViaCalculation.Orders.Calculations.CustomerDisplayName`) — a one-id-at-a-time
      interface would turn one query into one per order. Being able to make that decision
      here, on this side of the boundary, is a direct benefit of the interface being a
      function: the batching strategy is `Customers`' business, and changing it changes
      nothing in `Orders`.
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
