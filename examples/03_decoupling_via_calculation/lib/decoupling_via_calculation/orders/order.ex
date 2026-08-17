defmodule DecouplingViaCalculation.Orders.Order do
  @moduledoc """
  `DecouplingViaCalculation.Orders` exports this order through its
  domain-level `define`s.

  The AFTER state of this example lives in two lines of this file:

    * `attribute :customer_id, :uuid` is a plain attribute. This resource
      holds no `belongs_to :customer, DecouplingViaCalculation.Customers.Customer`
      relationship. An order records which customer placed it, and nothing
      else. It holds no reference to another domain's resource module, no
      expectation about that resource's attributes, and no ability to load
      its relationships.

    * `calculate :customer_display_name, :string, ...Calculations.CustomerDisplayName`
      replaces the relationship. It is an ordinary Ash calculation, loadable
      like any other (`load: [:customer_display_name]`). It gets its value by
      calling `DecouplingViaCalculation.Customers`' exported code interface.
      See `DecouplingViaCalculation.Orders.Calculations.CustomerDisplayName`.

  The BEFORE state holds the same resource with the relationship. That
  resource does not compile. It lives in this example's `antipattern/`
  directory. The README walks through reproducing its failure.
  """

  use Ash.Resource,
    domain: DecouplingViaCalculation.Orders,
    data_layer: Ash.DataLayer.Ets

  alias DecouplingViaCalculation.Orders.Calculations.CustomerDisplayName

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id

    # Just an id. Deliberately not a `belongs_to` to another domain's resource: see the
    # moduledoc, and `antipattern/orders/order.ex` for what that would look like.
    attribute :customer_id, :uuid, allow_nil?: false, public?: true

    attribute :item, :string, allow_nil?: false, public?: true
    attribute :quantity, :integer, allow_nil?: false, public?: true, default: 1
  end

  calculations do
    calculate :customer_display_name, :string, CustomerDisplayName do
      public? true
    end
  end

  actions do
    defaults [:read, create: [:customer_id, :item, :quantity]]
  end
end
