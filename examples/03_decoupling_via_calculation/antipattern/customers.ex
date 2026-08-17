defmodule DecouplingViaCalculation.Antipattern.Customers do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary]

  resources do
    resource DecouplingViaCalculation.Antipattern.Customers.Customer
  end
end
