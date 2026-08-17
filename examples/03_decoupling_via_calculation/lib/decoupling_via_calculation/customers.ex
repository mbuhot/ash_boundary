defmodule DecouplingViaCalculation.Customers do
  @moduledoc """
  The domain that owns customer data, and the *callee* side of this example's decoupling
  story. It publishes exactly one thing: a purpose-built interface for the questions
  other domains legitimately need answered about a customer.

  Two resources, exported very differently (the distinction sample project 2 covers in
  full):

    * `DecouplingViaCalculation.Customers.Customer` is named by a **bare** `resource`
      entry below — no domain-level `define` — so `AshBoundary` leaves it out of
      `exports`. It is the real, ETS-backed resource, and it is invisible outside this
      namespace. Its attribute names, its actions, its relationships and its struct are
      all free to change without any other domain being able to depend on them, because
      no other domain can reach the module at all.

    * `DecouplingViaCalculation.Customers.Directory` carries the domain-level `define`s,
      so it — and this domain module — are the only things this domain exports. It holds
      no data of its own; it is a deliberately narrow facade of generic actions over
      `Customer`, and it exists so that `Customer` never has to be exported to give
      another domain the two answers it actually needs:

          DecouplingViaCalculation.Customers.register_customer!(first_name, family_name)
          #=> a customer id

          DecouplingViaCalculation.Customers.customer_display_names!(ids)
          #=> %{customer_id => "Ada Lovelace"}

  ## Why a facade resource rather than `define`s on `Customer`

  `boundary`'s `exports` are module-level, not function-level (a limitation
  `AshBoundary`'s own docs call out and accept), so a domain-level `define` on `Customer`
  would necessarily export the whole `Customer` module: every caller in the app would
  get its struct, its other actions and its relationships along with the one function
  that was actually wanted. Putting the cross-domain interface on its own resource keeps
  the export surface equal to the interface, which is what makes the BEFORE state in this
  example's README a *permanent* compile error rather than one export away from
  compiling.

  This is a trade-off, not a rule: a domain whose consumers genuinely need `Customer`
  records — to receive one from a read action and hand it back to an update action —
  should just export it with a domain-level `define`, exactly as sample projects 1 and 2
  do. The facade earns its place when what the other side needs is an *answer*, not a
  record, which is precisely the case a relationship would otherwise be used for.
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
