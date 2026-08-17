defmodule DecouplingViaCalculation.Antipattern.Customers do
  @moduledoc """
  This directory holds the BEFORE state. It shows what not to do.

  No normal build compiles this directory. See `mix.exs`.
  Run `MIX_ENV=antipattern mix compile` to see the failure.
  Read this example's README for the full walkthrough.

  This domain owns a `Customer` resource.
  It has no domain-level `define` for `Customer`.
  The domain exports nothing but itself.
  This is the default state that `AshBoundary` protects.
  No domain outside `Customers` needs customer data yet.

  `DecouplingViaCalculation.Antipattern.Orders` gives an order a customer.
  It adds a relationship to do this.
  """

  use Ash.Domain, extensions: [AshBoundary]

  resources do
    resource DecouplingViaCalculation.Antipattern.Customers.Customer
  end
end
