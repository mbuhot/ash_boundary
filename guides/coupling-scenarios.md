# Coupling Scenarios

AshBoundary draws a compile-time line around each Ash domain. This guide shows
five common ways application code couples across that line, and the domain
shape that makes each one searchable or rejected.

Each scenario has the same three parts:

- a question a developer asks in a grown codebase,
- the wide contract that makes the question hard to answer,
- the narrow contract that answers it with a search, plus the check the
  compiler applies.

## Contracts and their size

Two domains that communicate share some knowledge. That shared knowledge is a
contract, and some coupling is the price of every contract. The size of the
contract decides the cost:

- A wide contract (a resource struct, a relationship, a table) shows every
  detail to every consumer. Each detail becomes load-bearing. Change becomes
  hard.
- A narrow contract (a few exported functions over a stable abstraction) lets
  the implementation change in isolation.

## The search test

One practical test judges every scenario. Two searches must explain a
resource's state:

1. Search the resource's own domain for its actions, changes, and hooks.
2. Search for the callers of the domain's exported code interface.

When the test passes, those two searches find the code responsible for each
state a resource can reach. When a coupling breaks the test, the writers and
the rules hide in distant parts of the codebase.

## Scenario 1: "Who cancelled this order?"

`MyApp.Support.Ticket` holds a relationship to an order in a different domain:

```elixir
relationships do
  belongs_to :order, MyApp.Orders.Order
end

actions do
  update :close do
    argument :order, :map, allow_nil?: false
    change manage_relationship(:order, on_match: :update)
  end
end
```

A relationship is a write path. The `:close` action on a ticket can set the
order's status through `manage_relationship`. An `after_action` hook on any
resource that holds the relationship can do the same.

The order reached the `:cancelled` state through a `Support` action:

- A search inside the `Orders` domain does not find the writer.
- A search for the callers of an `Orders` function does not find the writer.

The search test fails.

### The narrow contract

- Replace the relationship with a plain attribute: `attribute :order_id, :uuid`.
- Export a cancel action from `Orders` with a domain-level `define`.
- The `Support` action calls `MyApp.Orders.cancel_order/1`.

The writers of the `:cancelled` state are now the `Orders` domain plus the
callers of `cancel_order/1`. One search finds each set.

### The compiler check

Keep `MyApp.Orders.Order` internal: give it a bare `resource` entry, with no
domain-level `define`. The `belongs_to` in `Support` then fails compilation as
a forbidden reference. AshBoundary checks alias references, and a relationship
is an alias reference.

## Scenario 2: "We want to rename `family_name`"

Consumers receive `%Customer{}` structs and read fields from them. Every field
read in every domain is load-bearing. A rename inside `Customers` breaks
distant code at runtime.

### The narrow contract

Export one function that answers the caller's question:

```elixir
MyApp.Customers.customer_display_names!(ids)
#=> %{id => "Ada Lovelace"}
```

Callers receive answers. The rename stays inside `Customers`, together with
every other storage decision.

### The compiler check

Keep `Customer` internal. A struct match, an alias, or a function call on
`MyApp.Customers.Customer` outside the `Customers` namespace fails compilation.
See [Decoupling via Calculations](decoupling-with-calculations.md) for the
full pattern, and `examples/03_decoupling_via_calculation` for a runnable
project.

## Scenario 3: "Changing `User` touches every domain"

Policies across the application match on `%MyApp.Accounts.User{}` and read its
fields. The `User` resource becomes a contract with the whole codebase.

### The narrow contract

Define an explicit actor struct with three fields, as its own small boundary:

```elixir
defmodule MyApp.Actor do
  use Boundary

  @enforce_keys [:id, :role, :permissions]
  defstruct [:id, :role, :permissions]
end
```

- `Accounts` builds the `%MyApp.Actor{}` at sign-in.
- Each domain adds `MyApp.Actor` to its `deps` and writes policies against it:
  `actor_attribute_equals(:role, :admin)`.
- A name or an email requires a call to an exported `Accounts` function.

A domain's exports come from the `define` entries in its `resources` block, so
a plain struct module declares its own boundary with `use Boundary`.

### The compiler check

Keep `MyApp.Accounts.User` internal. A struct match or a function call on it
outside `Accounts` fails compilation. The policy expression `actor(:field)`
carries no module reference, so the compiler does not check it. The struct
closes that gap: `actor(:email)` finds no such field on `%MyApp.Actor{}`.

## Scenario 4: "Orders needs customer names, and Customers wants order counts"

Each domain lists the other in `deps`. The compilation fails: AshBoundary
reports the cycle and names both modules. Two domains that reach into each
other are one domain with two names, and the compiler forces a direction
decision.

Resolutions, in preference order:

1. Compose at a higher layer. The web or reporting layer declares deps on both
   domains, reads both, and joins in memory:

   ```elixir
   defmodule MyAppWeb do
     use Boundary, deps: [MyApp.Orders, MyApp.Customers]
   end
   ```

2. Move the computation to the domain that owns the data. Export
   `MyApp.Orders.order_counts!(customer_ids)` and let the caller fetch.
3. Extract a third domain that both depend on.

## Scenario 5: "The cancellation rule lives in a LiveView"

The domain exports generic actions:

```elixir
resource MyApp.Orders.Order do
  define :get_order, action: :read
  define :update_order, action: :update
end
```

The web layer holds the business rule:

```elixir
def handle_event("cancel", _params, socket) do
  order = Orders.get_order!(socket.assigns.order_id)

  if order.status == :pending do
    Orders.update_order!(order, %{status: :cancelled})
  end
  ...
end
```

The rule "only a pending order can be cancelled" lives in an event handler. A
second entry point (a JSON API, a background job, an admin page) either
re-implements the rule or skips it. A search inside the `Orders` domain does
not find the rule. The search test fails.

### The narrow contract

Encode the rule as a named action on the resource:

```elixir
update :cancel do
  validate attribute_equals(:status, :pending)
  change set_attribute(:status, :cancelled)
end
```

Export the intention-revealing interface and keep the generic `:update` off
the domain's `define` list:

```elixir
resource MyApp.Orders.Order do
  define :get_order, action: :read
  define :cancel_order, action: :cancel
end
```

The handler becomes one call: `Orders.cancel_order!(order_id)`. Every entry
point gets the same rule, and the rule lives in the domain.

### The compiler check

The exported surface is the domain's `define` list, so the web layer reaches
the domain through those functions. One gap needs a design rule: `boundary`
exports are module-level, and a returned record permits
`Ash.Changeset.for_update(record, :update)` with zero module references for
the compiler to check. Two habits close it: return ids and answers where a
caller needs no record, and put the validations on the actions themselves so
every path through Ash enforces them.

## Summary

| Scenario | Wide contract | Narrow contract | Compiler check |
| --- | --- | --- | --- |
| Side-channel writes | a cross-domain relationship | an exported action function | forbidden reference on the `belongs_to` |
| Field renames | a resource struct | a purpose-built function | forbidden reference on the struct match |
| Actor sprawl | the `User` resource | a three-field `%Actor{}` | forbidden reference on each `User` access |
| Mutual knowledge | `deps` in both directions | `deps` in one direction | a cycle error |
| Logic in the web layer | generic CRUD defines | intention-revealing actions | the `define` list bounds the exported surface |

Each narrow contract keeps the search test true: the domain plus the callers
of its exported interface explain every state a resource can reach.
