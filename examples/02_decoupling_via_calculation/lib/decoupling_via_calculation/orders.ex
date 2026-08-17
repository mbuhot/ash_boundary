defmodule DecouplingViaCalculation.Orders do
  @moduledoc """
  The orders domain.
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
