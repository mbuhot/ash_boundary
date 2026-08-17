defmodule DecouplingViaCalculation.Antipattern.Customers.Customer do
  @moduledoc """
  This module is part of the BEFORE state. No normal build compiles it.
  See `mix.exs` and the README.

  This resource matches the shipped `DecouplingViaCalculation.Customers.Customer`
  in purpose. It is an internal resource with its own display-name logic.

  Another domain's resource points a relationship at this module. This exposes
  the module's name, its attributes, and its struct to that domain at compile
  time.
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
