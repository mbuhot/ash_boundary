defmodule DecouplingViaCalculation.Customers do
  @moduledoc """
  The customers domain.
  """

  use Ash.Domain, extensions: [AshBoundary]

  resources do
    resource DecouplingViaCalculation.Customers.Customer

    resource DecouplingViaCalculation.Customers.Directory do
      define :register_customer, action: :register, args: [:first_name, :family_name]
      define :customer_display_names, action: :display_names, args: [:ids]
    end
  end
end
