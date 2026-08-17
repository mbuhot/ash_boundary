# Decoupling via Calculations

`AshBoundary` exists to make one specific mistake visible: a direct, resource-to-resource
relationship between two domains. This guide explains why that mistake is easy to make,
what it costs, and the one-sentence fix — replacing the relationship with a calculation
that calls the other domain's exported interface. For the full runnable version of
everything below, see
[`examples/03_decoupling_via_calculation`](https://github.com/mbuhot/ash_boundary/tree/main/examples/03_decoupling_via_calculation),
which ships both the "before" and "after" as real, compiling (and, for "before", real,
*failing to* compile) code.

## The mistake looks like ordinary Ash

Two domains, `Orders` and `Customers`. An order is placed by a customer, so naturally:

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

Nothing here is wrong Ash — it's exactly what the framework makes easy, and if
`Customers.Customer` were in the same domain as `Order` it would be the right call. The
problem is that it isn't. `Order` now names another domain's resource module at compile
time, and `load: [:customer]` issues a read against that domain's storage from code that
lives in `Orders`.

## What a cross-domain relationship actually costs

- **`Orders` cannot be compiled, or understood, without `Customers`.** The dependency is
  not a documented API call, it is a module reference baked into the relationship
  declaration.
- **`Orders` now queries another domain's storage.** `Customer` can no longer change data
  layer, move behind a service boundary, or add a required filter to its own reads
  without risking a query that lives in `Orders` and that `Customers` doesn't own.
- **`Orders` receives whole `Customer` structs**, and so does everything downstream of an
  order. Every attribute on `Customer` is now in reach of code that had no business
  seeing it, and any of it may quietly become load-bearing — renaming a field stops being
  a local change.
- **It grows.** The natural next step is `has_many :orders` back on `Customer`. Once both
  directions exist, the two domains are one domain wearing two names.

None of this shows up in the diff that introduces the relationship, and none of it is
caught by `boundary` on its own — a relationship *names* a module without calling
anything on it, which is exactly the kind of reference `boundary` does not check unless
alias checking is turned on. `AshBoundary` turns it on for every domain it declares (see
the "Relationships are checked, because aliases are checked" section of the
`AshBoundary` moduledoc), which is precisely what makes the mistake visible instead of
silent.

## The fix: an id, an exported answer, and a calculation

Three changes, and they are the entire pattern.

**1. The relationship becomes a plain attribute.**

```elixir
# Orders.Order
attribute :customer_id, :uuid, allow_nil?: false
```

An order records *which* customer placed it — an opaque id, not a module reference and
not a loadable struct.

**2. `Customers` exports a purpose-built interface, not the resource.**

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

`Directory` is a small resource with no data layer of its own, holding a generic action
that answers exactly the question `Orders` needs answered: given a list of ids, return
their display names. Callers get answers, never records.

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

Declared like any other calculation, and loaded like any other calculation:

```elixir
calculate :customer_display_name, :string, CustomerDisplayName do
  public? true
end
```

What crosses the boundary is one function call: a list of ids in, a map of strings out.
`Customers.Customer` — its attributes, its data layer, its actions — never crosses at
all, and because it isn't exported, the compiler now rejects any attempt to reach it
directly from `Orders`.

## Why the interface takes a list, not one id at a time

Ash calls a calculation's `calculate/3` once with the *entire batch* of records being
loaded, whether that's one order or a thousand. Shaping `Customers`' exported interface
around that access pattern — a list of ids in, a map of answers out — means loading
`:customer_display_name` over any number of orders costs exactly one call into
`Customers`, never one call per record. "You can't join a function call" is the fair
objection to this pattern in general; the answer is to design the exported function
around how it's actually called, not to accept N calls where a relationship would have
issued one query.

Note where that decision lives: entirely inside `Customers`, behind the interface.
`Customers` is free to change how `display_names` is computed — caching, batching, a
different storage engine entirely — without `Orders` changing a line. A relationship
would have put that decision in `Orders`' own query.

## The trade-off, honestly

`boundary`'s exports are module-level, not member-level: there is no way to export "just
the struct" of a resource while keeping its functions private. So the alternative to a
calculation — giving `Customer` a domain-level `define` so it can be exported and
related to directly — exports the *entire* `Customer` module to the entire app, and
`boundary` stops helping with it anywhere. That's a fine trade when a caller genuinely
needs the record (see `examples/01_basic_boundary` and `examples/02_exported_vs_internal`,
both of which export a resource this way, deliberately). It's the wrong trade when it's
done only to let a relationship compile — see
[`examples/03_decoupling_via_calculation`'s "The escape hatch, and why it is not one"](https://github.com/mbuhot/ash_boundary/tree/main/examples/03_decoupling_via_calculation#the-escape-hatch-and-why-it-is-not-one)
for that exact scenario, verified rather than asserted.

The rule of thumb: when another domain needs an **answer**, give it a purpose-built
interface and keep the resource internal. When another domain genuinely needs the
**record**, export the resource with a domain-level `define` and accept that its module
is now public. A cross-domain relationship is almost always the case where it looks like
you need the record but you actually needed an answer.

## See it run

[`examples/03_decoupling_via_calculation`](https://github.com/mbuhot/ash_boundary/tree/main/examples/03_decoupling_via_calculation)
ships both states as real code:

- `antipattern/` — the relationship above, kept out of the example's normal build and
  compiled only via `MIX_ENV=antipattern mix compile`, whose entire purpose is to show
  `boundary` refusing it.
- `lib/` — the calculation-based fix, with a test that loads `:customer_display_name`
  from outside both domains and asserts on a real name computed from the other domain's
  own storage.

[`examples/04_deliberate_violation`](https://github.com/mbuhot/ash_boundary/tree/main/examples/04_deliberate_violation)
takes the same pattern one step further: it automates the "the compiler catches this" claim
as a real, `mix test`-run assertion on a real `mix compile --warnings-as-errors` exit code,
rather than a README walkthrough you have to reproduce by hand.
