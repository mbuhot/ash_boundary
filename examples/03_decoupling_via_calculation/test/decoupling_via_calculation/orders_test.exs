defmodule DecouplingViaCalculation.OrdersTest do
  use ExUnit.Case, async: true

  alias DecouplingViaCalculation.Customers
  alias DecouplingViaCalculation.Orders

  test "an order's customer_display_name comes from the Customers domain, not from Orders" do
    customer_id = Customers.register_customer!("Ada", "Lovelace")

    order = Orders.place_order!(%{customer_id: customer_id, item: "Difference engine"})

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

    order = Orders.place_order!(%{customer_id: unknown, item: "Lost cause"})

    assert Orders.get_order!(order.id, load: [:customer_display_name]).customer_display_name ==
             nil
  end
end
