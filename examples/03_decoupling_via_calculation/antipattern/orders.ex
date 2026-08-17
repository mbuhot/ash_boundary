defmodule DecouplingViaCalculation.Antipattern.Orders do
  @moduledoc """
  **BEFORE state — not compiled by any normal build. See `mix.exs` and the README.**

  Note that this domain does everything right on its own terms. It declares the
  cross-domain dependency it has, in exactly the reviewable line `AshBoundary` asks for:

      boundary do
        deps [DecouplingViaCalculation.Antipattern.Customers]
      end

  Declaring the dep is necessary and not sufficient. It grants access to what
  `DecouplingViaCalculation.Antipattern.Customers` *exports* — which is only the domain
  module — and the relationship in
  `DecouplingViaCalculation.Antipattern.Orders.Order` reaches past that, straight at the
  `Customer` resource module. That is the violation, and no `deps` entry can make it go
  away: the only ways out are to export `Customer` wholesale, or to stop reaching for it
  (the shipped `DecouplingViaCalculation.Orders`).
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
