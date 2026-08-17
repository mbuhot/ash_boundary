defmodule DecouplingViaCalculation.Antipattern.Orders.Order do
  @moduledoc """
  This module is part of the BEFORE state. No normal build compiles it.
  See `mix.exs` and the README.

  This file holds the anti-pattern: one `belongs_to`. An order in one domain
  holds a live Ash relationship to a resource in another domain.

  This is a natural thing to write. It works until someone changes `Customer`.
  The relationship costs four things:

    * `DecouplingViaCalculation.Antipattern.Customers.Customer` is named here at
      compile time. `Orders` cannot compile without it.
    * `Order`'s queries reach into another domain's data layer. `load: [:customer]`
      below issues a read against customer storage. `Customer` cannot change its
      data layer, or move behind a service call, without breaking this query.
    * `Order` receives whole `Customer` structs. Every consumer of an order can
      read every customer attribute. Renaming `family_name` becomes a
      cross-domain change.
    * The entanglement grows in both directions. The next step is
      `has_many :orders, ...Antipattern.Orders.Order` on `Customer`. This domain
      has declared no `deps` at all.

  The compiler refuses this file. See the README.
  """

  use Ash.Resource,
    domain: DecouplingViaCalculation.Antipattern.Orders,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id
    attribute :item, :string, allow_nil?: false, public?: true
    attribute :quantity, :integer, allow_nil?: false, public?: true, default: 1
  end

  relationships do
    # The violation. `Customer` is not exported by
    # `DecouplingViaCalculation.Antipattern.Customers`, and a declared `deps` entry does
    # not reach past another boundary's exports.
    belongs_to :customer, DecouplingViaCalculation.Antipattern.Customers.Customer do
      allow_nil? false
      attribute_writable? true
      public? true
    end
  end

  actions do
    defaults [:read, create: [:item, :quantity, :customer_id]]

    read :with_customer do
      prepare build(load: [:customer])
    end
  end
end
