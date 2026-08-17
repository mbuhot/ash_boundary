defmodule DecouplingViaCalculation.Customers.Customer do
  @moduledoc """
  The real customer resource — and **internal**, because
  `DecouplingViaCalculation.Customers` names it with a bare `resource` entry, with no
  domain-level `define`.

  Everything about its shape is private to the `DecouplingViaCalculation.Customers`
  boundary, and this example leans on that deliberately: a display name here is
  `first_name` and `family_name` joined, which is knowledge no other domain has, or
  could acquire — the `:display_name` calculation below is the only place it exists.
  Splitting the name differently, renaming an attribute, or moving the whole thing behind
  a different data layer is a local change, because the only code that can see any of it
  lives under `DecouplingViaCalculation.Customers.*`.

  The `code_interface` block makes `Customer` comfortable to call *from inside its own
  domain* (`DecouplingViaCalculation.Customers.Directory` is the only caller). As sample
  project 2 shows in detail, a resource-level `code_interface` has no effect on exports:
  these functions are real and callable, and only from within this namespace.
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
