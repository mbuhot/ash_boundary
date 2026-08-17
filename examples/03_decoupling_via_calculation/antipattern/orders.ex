defmodule DecouplingViaCalculation.Antipattern.Orders do
  @moduledoc false

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
