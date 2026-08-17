defmodule DecouplingViaCalculation.Antipattern.Orders.Order do
  @moduledoc """
  **BEFORE state — not compiled by any normal build. See `mix.exs` and the README.**

  The anti-pattern itself, in one `belongs_to`: an order in one domain holding a live Ash
  relationship to a resource owned by another domain.

  It is the natural thing to write, and it works fine right up until somebody wants to
  change `Customer`. What this file actually buys:

    * `DecouplingViaCalculation.Antipattern.Customers.Customer` is named here, at compile
      time, so `Orders` cannot be compiled — or reasoned about — without it.
    * `Order`'s queries now reach into another domain's data layer. `load: [:customer]`
      below is `Orders` issuing a read against customer storage, so the two resources'
      storage decisions are joined: `Customer` cannot move to another data layer, or
      behind a service call, without breaking this query.
    * `Order` receives whole `Customer` structs, so every consumer of an order can now
      read every customer attribute, and any of them may quietly come to depend on one.
      Renaming `family_name` becomes a cross-domain change.
    * The entanglement is mutual and grows: the natural next step is
      `has_many :orders, ...Antipattern.Orders.Order` on `Customer`, which is the same
      violation in the other direction (and, this time, from a domain that has declared
      no `deps` at all).

  None of that is hypothetical bookkeeping — the compiler refuses it. See the README.
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
