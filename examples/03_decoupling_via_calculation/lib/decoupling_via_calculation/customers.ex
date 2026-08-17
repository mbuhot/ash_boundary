defmodule DecouplingViaCalculation.Customers do
  @moduledoc """
  This domain owns customer data. It is the callee side of this example's
  decoupling story. It publishes one purpose-built interface. Other domains ask
  this interface their questions about a customer.

  The domain exports two resources very differently:

    * `DecouplingViaCalculation.Customers.Customer` is named by a bare `resource`
      entry below, with no domain-level `define`. `AshBoundary` leaves it out of
      `exports`. This is the real, ETS-backed resource. No code outside this
      namespace can see it. Its attribute names, actions, relationships, and
      struct stay free to change, because no other domain can reach the module.

    * `DecouplingViaCalculation.Customers.Directory` carries the domain-level
      `define`s. This domain exports only `Directory` and the domain module
      itself. `Directory` holds no data of its own. It is a narrow facade of
      generic actions over `Customer`. It gives another domain the two answers
      it needs, without exporting `Customer`:

          DecouplingViaCalculation.Customers.register_customer!(first_name, family_name)
          #=> a customer id

          DecouplingViaCalculation.Customers.customer_display_names!(ids)
          #=> %{customer_id => "Ada Lovelace"}

  ## Why a facade resource rather than `define`s on `Customer`

  `boundary`'s `exports` work at module level. They do not work at function
  level (`AshBoundary`'s docs state this limitation). A domain-level `define` on
  `Customer` would export the whole `Customer` module. Every caller in the app
  would then get its struct, its other actions, and its relationships, along
  with the one wanted function. A cross-domain interface on its own resource
  keeps the export surface equal to the interface. This is why the BEFORE state
  in this example's README is a permanent compile error.

  This is a trade-off. A domain whose consumers genuinely need `Customer`
  records should export it with a domain-level `define`, as sample projects 1
  and 2 do. The facade earns its place when the other side needs an answer, and
  a relationship would otherwise supply the record it does not need.
  """

  use Ash.Domain, extensions: [AshBoundary]

  resources do
    # Internal: no domain-level define, so `AshBoundary` leaves it out of `exports` and
    # nothing outside `DecouplingViaCalculation.Customers.*` can reference it.
    resource DecouplingViaCalculation.Customers.Customer

    # Exported: this is the entire public API of this domain.
    resource DecouplingViaCalculation.Customers.Directory do
      define :register_customer, action: :register, args: [:first_name, :family_name]
      define :customer_display_names, action: :display_names, args: [:ids]
    end
  end
end
