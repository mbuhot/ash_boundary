defmodule DecouplingViaCalculation.Orders do
  @moduledoc """
  The domain that owns orders, and the *caller* side of this example's decoupling story.

  `boundary do deps [...] end` is the whole reason this section exists in `AshBoundary`:
  `DecouplingViaCalculation.Customers` is a **sibling** boundary, so nothing here may
  reference it until this domain admits, in one reviewable line, that it depends on it.
  `deps` is never inferred — see the `AshBoundary` moduledoc — precisely so that adding a
  cross-domain dependency is a decision somebody makes rather than a side effect of a
  line of code.

  What that dep buys is narrow: `DecouplingViaCalculation.Customers`' *exports*, which
  are the domain module and its `Directory` facade. `Customers.Customer` itself is not
  exported, so no amount of `deps` makes a direct relationship to it legal — which is
  exactly the BEFORE state this example teaches against (see the README, and
  `antipattern/`).

  The one place this domain crosses the line is
  `DecouplingViaCalculation.Orders.Calculations.CustomerDisplayName`, a normal Ash
  calculation that calls the exported function
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
