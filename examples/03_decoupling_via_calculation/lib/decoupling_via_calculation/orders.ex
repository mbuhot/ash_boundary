defmodule DecouplingViaCalculation.Orders do
  @moduledoc """
  This domain owns orders. It is the caller side of this example's decoupling
  story.

  `DecouplingViaCalculation.Customers` is a sibling boundary. No code here may
  reference it until this domain declares `boundary do deps [...] end` in one
  reviewable line. `AshBoundary` never infers `deps`. Adding a cross-domain
  dependency stays a decision someone makes, not a side effect of a line of
  code.

  This dependency grants access to `DecouplingViaCalculation.Customers`'
  exports only: the domain module and its `Directory` facade.
  `Customers.Customer` stays unexported. No `deps` entry makes a direct
  relationship to it legal. This is the BEFORE state this example teaches
  against (see the README and `antipattern/`).

  `DecouplingViaCalculation.Orders.Calculations.CustomerDisplayName` is the
  one place this domain crosses the boundary. It is a normal Ash calculation.
  It calls the exported function
  `DecouplingViaCalculation.Customers.customer_display_names!/1`.
  """

  use Ash.Domain, extensions: [AshBoundary]

  boundary do
    deps [DecouplingViaCalculation.Customers]
  end

  resources do
    resource DecouplingViaCalculation.Orders.Order do
      define :place_order, action: :create
      define :get_order, action: :read, get_by: [:id]
    end
  end
end
