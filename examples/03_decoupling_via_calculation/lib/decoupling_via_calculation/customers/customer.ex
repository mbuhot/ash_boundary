defmodule DecouplingViaCalculation.Customers.Customer do
  @moduledoc """
  This is the real customer resource. It is internal.
  `DecouplingViaCalculation.Customers` names it with a bare `resource` entry.
  It has no domain-level `define`.

  Its shape stays private to the `DecouplingViaCalculation.Customers` boundary.
  A display name here is `first_name` and `family_name` joined. No other domain
  has this knowledge or can acquire it. The `:display_name` calculation below is
  the only place it exists.
  Splitting the name differently, renaming an attribute, or moving the data to
  another data layer is a local change. Only code under
  `DecouplingViaCalculation.Customers.*` can see any of it.

  The `code_interface` block makes `Customer` callable from inside its own
  domain. `DecouplingViaCalculation.Customers.Directory` is the only caller.
  A resource-level `code_interface` has no effect on exports (sample project 2
  covers this in detail). These functions stay callable only from within this
  namespace.
  """

  use Ash.Resource,
    domain: DecouplingViaCalculation.Customers,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id
    attribute :first_name, :string, allow_nil?: false, public?: true
    attribute :family_name, :string, allow_nil?: false, public?: true
  end

  calculations do
    # The one and only definition of "what do we call this customer" — internal to this
    # domain, and reachable from other domains only as the string it produces.
    calculate :display_name, :string, expr(string_join([first_name, family_name], " "))
  end

  actions do
    defaults [:read, create: [:first_name, :family_name]]

    read :by_ids do
      argument :ids, {:array, :uuid}, allow_nil?: false
      filter expr(id in ^arg(:ids))
      prepare build(load: [:display_name])
    end
  end

  code_interface do
    define :create
    define :by_ids, action: :by_ids, args: [:ids]
  end
end
