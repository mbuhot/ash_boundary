# Decoupling via Calculations

AshBoundary makes one specific mistake visible: a direct resource-to-resource
relationship between two domains. This guide explains the cost of that
relationship and the fix. The fix replaces the relationship with a calculation
that calls the other domain's exported interface.
[`examples/03_decoupling_via_calculation`](https://github.com/mbuhot/ash_boundary/tree/main/examples/03_decoupling_via_calculation)
ships the "before" and the "after" as runnable code.

## The mistake looks like ordinary Ash

Two domains, `Orders` and `Customers`. A customer places an order, so the
natural declaration is:

```elixir
# Orders.Order
relationships do
  belongs_to :customer, MyApp.Customers.Customer do
    allow_nil? false
  end
end

actions do
  read :with_customer do
    prepare build(load: [:customer])
  end
end
```

This is correct Ash. If `Customer` lived in the same domain as `Order`, this
declaration would be the right call. Across a domain line it has two effects:

- `Order` names another domain's resource module at compile time.
- `load: [:customer]` issues a read against the other domain's storage, from
  code that lives in `Orders`.

## What a cross-domain relationship costs

- Compilation of `Orders` requires `Customers`. The dependency is a module
  reference inside the relationship declaration.
- `Orders` queries the storage of `Customers`. A data-layer change, a service
  boundary, or a required read filter in `Customers` breaks a query that lives
  in `Orders`.
- `Orders` receives whole `Customer` structs, and so does everything
  downstream of an order. Each field read becomes load-bearing, so a field
  rename stops being a local change.
- The coupling grows. The natural next step is `has_many :orders` on
  `Customer`. With both directions in place, the two domains are one domain
  with two names.

The diff that adds the relationship does not show these costs. A relationship
names a module and calls no function on it, and `boundary` checks that kind of
reference only when alias checking is on. AshBoundary turns alias checking on
for every domain it declares, which makes the mistake visible. See the
`AshBoundary` moduledoc.

## The fix: an id, an exported answer, and a calculation

Three changes make the entire pattern.

**1. The relationship becomes a plain attribute.**

```elixir
# Orders.Order
attribute :customer_id, :uuid, allow_nil?: false
```

An order records the id of the customer that placed it. The attribute holds no
module reference and loads no struct.

**2. `Customers` exports a purpose-built interface.**

```elixir
# Customers domain
resources do
  # Internal: no domain-level `define`, so it's never exported.
  resource MyApp.Customers.Customer

  # Exported: this is the domain's entire public API.
  resource MyApp.Customers.Directory do
    define :customer_display_names, action: :display_names, args: [:ids]
  end
end
```

`Directory` is a small resource with no data layer. It holds one generic
action that answers the question `Orders` asks: a list of ids in, display
names out. Callers receive answers. Callers receive no records.

**3. `Order` gains a calculation that calls that interface.**

```elixir
defmodule MyApp.Orders.Calculations.CustomerDisplayName do
  use Ash.Resource.Calculation

  alias MyApp.Customers

  @impl true
  def load(_query, _opts, _context), do: [:customer_id]

  @impl true
  def calculate(orders, _opts, _context) do
    display_names =
      orders
      |> Enum.map(& &1.customer_id)
      |> Customers.customer_display_names!()

    {:ok, Enum.map(orders, &Map.get(display_names, &1.customer_id))}
  end
end
```

Declare and load it like any other calculation:

```elixir
calculate :customer_display_name, :string, CustomerDisplayName do
  public? true
end
```

One function call crosses the boundary: a list of ids in, a map of strings
out. `Customers.Customer` stays inside its own domain, and the compiler
rejects a direct reference to it from `Orders`.

## Why the interface takes a list

Ash calls a calculation's `calculate/3` once, with the entire batch of records
being loaded, for one order or a thousand. The exported interface takes a list
of ids and returns a map of answers, so a load of `:customer_display_name`
makes one call into `Customers` for any number of orders. Shape an exported
function around the access pattern of its caller.

That decision lives inside `Customers`, behind the interface. `Customers` can
change its caching, its batching, or its storage engine without a change in
`Orders`.

## The trade-off

`boundary` exports are module-level. An export includes every function on the
module. The alternative fix gives `Customer` a domain-level `define`, which
exports the whole `Customer` module to the entire app and removes `boundary`'s
protection for it everywhere. That trade is right when a caller needs the
record: `examples/01_basic_boundary` and `examples/02_exported_vs_internal`
both export a resource this way, deliberately. That trade is wrong when its
only purpose is to let a relationship compile. See
[the escape hatch section of `examples/03_decoupling_via_calculation`](https://github.com/mbuhot/ash_boundary/tree/main/examples/03_decoupling_via_calculation#the-escape-hatch-and-why-it-is-not-one)
for that exact scenario.

The rule: when another domain needs an answer, export a purpose-built
interface and keep the resource internal. When another domain needs the
record, export the resource with a domain-level `define` and accept that the
module is public. In most cross-domain relationships, the caller needs an
answer.

## See it run

[`examples/03_decoupling_via_calculation`](https://github.com/mbuhot/ash_boundary/tree/main/examples/03_decoupling_via_calculation)
ships both states as real code:

- `antipattern/` holds the relationship above. The normal build excludes it.
  `MIX_ENV=antipattern mix compile` compiles it and shows `boundary` refusing
  it.
- `lib/` holds the calculation-based fix, with a test that loads
  `:customer_display_name` from outside both domains and asserts on a real
  name computed from the other domain's storage.

[`examples/04_deliberate_violation`](https://github.com/mbuhot/ash_boundary/tree/main/examples/04_deliberate_violation)
automates the "the compiler catches this" claim: a test asserts on the exit
code of a real `mix compile --warnings-as-errors` run.
