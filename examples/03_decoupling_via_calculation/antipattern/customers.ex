defmodule DecouplingViaCalculation.Antipattern.Customers do
  @moduledoc """
  **This directory is the BEFORE state: what NOT to do.** Nothing here is compiled by any
  normal build — see this example's `mix.exs` — because it does not compile. Run
  `MIX_ENV=antipattern mix compile` to watch it fail, and read this example's README for
  the walkthrough.

  A perfectly ordinary customers domain, in the state every domain starts in: it owns a
  `Customer` resource, has no domain-level `define` for it, and therefore exports nothing
  but itself. That is not an oversight — it is the default `AshBoundary` exists to
  protect. Nobody outside this domain has needed customer data yet.

  Then `DecouplingViaCalculation.Antipattern.Orders` decides an order should have a
  customer, and reaches for the obvious tool: a relationship.
  """

  use Ash.Domain, extensions: [AshBoundary]

  resources do
    resource DecouplingViaCalculation.Antipattern.Customers.Customer
  end
end
