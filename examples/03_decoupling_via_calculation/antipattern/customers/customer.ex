defmodule DecouplingViaCalculation.Antipattern.Customers.Customer do
  @moduledoc """
  **BEFORE state — not compiled by any normal build. See `mix.exs` and the README.**

  Identical in spirit to the shipped `DecouplingViaCalculation.Customers.Customer`: an
  internal resource, with its own private notion of what a display name is.

  The difference is what happens to it. Here, another domain's resource points a
  relationship at this module, so this module's name, its attributes and its struct all
  become part of another domain's compile-time reality.
  """

  use Ash.Resource,
    domain: DecouplingViaCalculation.Antipattern.Customers,
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
    calculate :display_name, :string, expr(string_join([first_name, family_name], " "))
  end

  actions do
    defaults [:read, create: [:first_name, :family_name]]
  end
end
