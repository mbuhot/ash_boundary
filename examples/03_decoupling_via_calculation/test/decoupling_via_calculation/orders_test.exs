defmodule DecouplingViaCalculation.OrdersTest do
  @moduledoc """
  Proves the AFTER state works end to end, for real: customers are registered through
  `DecouplingViaCalculation.Customers`' exported interface, orders are placed through
  `DecouplingViaCalculation.Orders`' exported interface, and loading the
  `:customer_display_name` calculation returns names that came out of the *other domain's*
  ETS-backed `Customer` resource.

  Everything here runs through real Ash actions against the real ETS data layer. Nothing
  is mocked or stubbed: if the calculation were not genuinely calling into
  `DecouplingViaCalculation.Customers`, these assertions could not pass, because `Orders`
  stores no customer name anywhere — only a `customer_id`.

  This test module also sits *outside* both domains' namespaces, so it is restricted to
  exactly what they export — the same position any real consumer is in.
  """

  use ExUnit.Case, async: true

  alias DecouplingViaCalculation.Customers
  alias DecouplingViaCalculation.Orders

  test "an order's customer_display_name comes from the Customers domain, not from Orders" do
    customer_id = Customers.register_customer!("Ada", "Lovelace")

    order = Orders.place_order!(%{customer_id: customer_id, item: "Difference engine"})

    # Orders stores only the id: there is nowhere for a name to be hiding.
    assert order.customer_id == customer_id
    refute Map.has_key?(order, :first_name)
    assert %Ash.NotLoaded{} = order.customer_display_name

    loaded = Orders.get_order!(order.id, load: [:customer_display_name])

    assert loaded.customer_display_name == "Ada Lovelace"
  end

  test "loading the calculation over a batch of orders resolves each one's own customer" do
    ada = Customers.register_customer!("Ada", "Lovelace")
    grace = Customers.register_customer!("Grace", "Hopper")

    orders = [
      Orders.place_order!(%{customer_id: ada, item: "Punch cards", quantity: 500}),
      Orders.place_order!(%{customer_id: grace, item: "Compiler", quantity: 1}),
      Orders.place_order!(%{customer_id: ada, item: "Notebook", quantity: 2})
    ]

    # One `Ash.load!` over three records means one `calculate/3` call, which means one
    # call across the boundary into `Customers` — see the calculation's moduledoc.
    assert orders
           |> Ash.load!([:customer_display_name])
           |> Enum.map(& &1.customer_display_name) ==
             ["Ada Lovelace", "Grace Hopper", "Ada Lovelace"]
  end

  test "the exported interface answers by id, and says nothing at all about unknown ones" do
    ada = Customers.register_customer!("Ada", "Lovelace")
    unknown = Ash.UUID.generate()

    assert Customers.customer_display_names!([ada]) == %{ada => "Ada Lovelace"}
    assert Customers.customer_display_names!([unknown]) == %{}

    # The contract `Orders` depends on is exactly this map lookup, so an order pointing at
    # a customer that no longer exists resolves to `nil` rather than crashing or leaking a
    # half-loaded record from the other domain.
    order = Orders.place_order!(%{customer_id: unknown, item: "Lost cause"})

    assert Orders.get_order!(order.id, load: [:customer_display_name]).customer_display_name ==
             nil
  end
end
