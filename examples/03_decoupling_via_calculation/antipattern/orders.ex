defmodule DecouplingViaCalculation.Antipattern.Orders do
  @moduledoc """
  This module is part of the BEFORE state. No normal build compiles it.
  See `mix.exs` and the README.

  This domain declares its cross-domain dependency correctly:

      boundary do
        deps [DecouplingViaCalculation.Antipattern.Customers]
      end

  This declaration is necessary. It is not sufficient.
  The declaration grants access only to what
  `DecouplingViaCalculation.Antipattern.Customers` exports: the domain module.
  The relationship in `DecouplingViaCalculation.Antipattern.Orders.Order` reaches
  past that export and references the `Customer` resource module directly.
  This is the violation. No `deps` entry fixes it.
  Two fixes exist: export `Customer` wholesale, or remove the relationship.
  The shipped `DecouplingViaCalculation.Orders` removes the relationship.
  """

  use Ash.Domain, extensions: [AshBoundary]

  boundary do
    deps [DecouplingViaCalculation.Antipattern.Customers]
  end

  resources do
    resource DecouplingViaCalculation.Antipattern.Orders.Order do
      define :place_order, action: :create
      define :get_order, action: :read, get_by: [:id]
    end
  end
end
