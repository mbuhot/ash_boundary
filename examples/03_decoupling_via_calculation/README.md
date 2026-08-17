# 03: Decoupling a cross-domain relationship into a calculation

This example shows two Ash domains with a direct resource-to-resource
relationship between them. It then replaces that relationship with a
calculation. The calculation calls the other domain's exported function.
This is sample project 3 of 4 from the AshBoundary project goal.

Both states are here:

- **BEFORE** is `antipattern/`. It has four files. It is a real Ash app with
  `Order belongs_to Customer` across a domain line. It does not compile under
  boundary enforcement. `mix.exs` excludes it from every normal build. Compile
  it only with `MIX_ENV=antipattern mix compile`, whose entire purpose is to
  fail. This README reproduces its output verbatim below.
- **AFTER** is `lib/`, the shipped example. It compiles with
  `--warnings-as-errors`. `mix test` proves the calculation returns real data
  from the other domain, through real Ash actions, against the ETS data layer.

## The two domains

| Module | Exported? | Role |
| --- | --- | --- |
| `DecouplingViaCalculation.Customers` | yes (a boundary's root always is) | domain that owns customer data |
| `DecouplingViaCalculation.Customers.Customer` | **no** | the real, ETS-backed resource. Attributes `first_name`/`family_name`, a `:display_name` calculation, its own `code_interface` for use inside the domain |
| `DecouplingViaCalculation.Customers.Directory` | yes | the domain's entire public API: two generic actions, `:register` and `:display_names` |
| `DecouplingViaCalculation.Orders` | yes | domain that owns orders. `boundary do deps [...Customers] end` |
| `DecouplingViaCalculation.Orders.Order` | yes | has `attribute :customer_id, :uuid` and no relationship, plus the `:customer_display_name` calculation |
| `DecouplingViaCalculation.Orders.Calculations.CustomerDisplayName` | no (internal to `Orders`) | the calculation module. The only code in `Orders` that mentions `Customers` at all |
| `DecouplingViaCalculation` | — | the app's root boundary, plain `use Boundary`, mandatory in every example (see sample 1) |

`AshBoundary.Declaration.definition/1` reads the computed declarations back off
the compiled modules:

```
DecouplingViaCalculation:           []
DecouplingViaCalculation.Customers: [exports: [Directory], deps: []]
DecouplingViaCalculation.Orders:    [exports: [Order], deps: [DecouplingViaCalculation.Customers]]
```

`Customers` exports exactly one module. That module is `Directory`, not
`Customer`.

## BEFORE: the relationship, and what it costs

`antipattern/orders/order.ex`:

```elixir
relationships do
  belongs_to :customer, DecouplingViaCalculation.Antipattern.Customers.Customer do
    allow_nil? false
    attribute_writable? true
    public? true
  end
end

actions do
  defaults [:read, create: [:item, :quantity, :customer_id]]

  read :with_customer do
    prepare build(load: [:customer])
  end
end
```

This is the natural thing to write. It is correct Ash. Its cost does not show
in the diff that adds it:

- **`Orders` cannot compile, or be understood, without `Customers`.** The
  resource module of another domain is named here at compile time.
- **`Orders` now queries another domain's storage.** `load: [:customer]`
  issues a read against customer data from order code. `Customer` can no
  longer change data layer, move behind a service call, or add a required
  filter or preparation to its reads, without breaking a query that lives in
  `Orders`.
- **`Orders` now receives whole `Customer` structs**, and so does everything
  downstream of an order. Code with no business seeing a customer attribute
  can now reach it, and any of it may quietly become load-bearing. Renaming
  `family_name` stops being a local change.
- **The entanglement is mutual, and it grows.** The natural next step is
  `has_many :orders, ...Orders.Order` on `Customer`. That is the same
  violation in the other direction, from a domain that declared no `deps` at
  all. At that point the two domains are one domain with two names.

The BEFORE domain does not cheat. `antipattern/orders.ex` declares the
dependency honestly, in exactly the line AshBoundary asks for.

```elixir
boundary do
  deps [DecouplingViaCalculation.Antipattern.Customers]
end
```

This declaration is necessary. It is not sufficient: a `deps` entry grants
access to what the other boundary **exports**, and `Customer` is not
exported. See "Reproducing the BEFORE state yourself" below for the compiler
refusing it.

## AFTER: an id, plus a calculation over an exported function

Three changes make up the entire pattern.

**1. The relationship becomes a plain id.**
`lib/decoupling_via_calculation/orders/order.ex`:

```elixir
attribute :customer_id, :uuid, allow_nil?: false, public?: true
```

An order records which customer placed it. It holds no module reference, no
expectation about that module's attributes, and no ability to load anything
from it.

**2. `Customers` exports a purpose-built interface.**
`lib/decoupling_via_calculation/customers.ex`:

```elixir
resources do
  # Internal: no domain-level define.
  resource DecouplingViaCalculation.Customers.Customer

  # Exported: the entire public API of this domain.
  resource DecouplingViaCalculation.Customers.Directory do
    define :register_customer, action: :register, args: [:first_name, :family_name]
    define :customer_display_names, action: :display_names, args: [:ids]
  end
end
```

`Directory` is a resource with no data layer and no attributes. It holds two
generic actions over the internal `Customer`. `:register` returns an **id**,
not a record. `:display_names` takes a **list of ids** and returns
`%{id => "Ada Lovelace"}`. Callers get answers. They never get a `Customer`.

**3. `Order` gains a calculation that calls that interface.**
`lib/decoupling_via_calculation/orders/calculations/customer_display_name.ex`:

```elixir
defmodule DecouplingViaCalculation.Orders.Calculations.CustomerDisplayName do
  use Ash.Resource.Calculation

  alias DecouplingViaCalculation.Customers

  @impl Ash.Resource.Calculation
  def load(_query, _opts, _context), do: [:customer_id]

  @impl Ash.Resource.Calculation
  def calculate(orders, _opts, _context) do
    display_names =
      orders
      |> Enum.map(& &1.customer_id)
      |> Customers.customer_display_names!()

    {:ok, Enum.map(orders, &Map.get(display_names, &1.customer_id))}
  end
end
```

The resource declares it as an ordinary calculation, loadable like any other:

```elixir
calculate :customer_display_name, :string, CustomerDisplayName do
  public? true
end

# ...
Orders.get_order!(order.id, load: [:customer_display_name]).customer_display_name
#=> "Ada Lovelace"
```

One function call crosses the boundary: a list of ids in, a map of strings
out. These things do not cross it:

- `DecouplingViaCalculation.Customers.Customer`. `Orders` never references it,
  and `Customers` does not export it, so no code can reference it even by
  accident. The compiler enforces this; the "Reproducing" section below shows
  it refusing exactly that.
- Customer attribute names. `first_name` and `family_name` appear nowhere in
  `Orders`. Splitting the name differently, renaming a field, or changing what
  a display name means stays a local change inside `Customers`, invisible to
  `Orders`, as long as `customer_display_names/1` still answers the same
  question.
- Customer's data layer, actions, filters, and preparations. `Orders` issues
  no query against customer data. It asks a question through a function.

One dependency remains: a contract. `Orders` depends on
`Customers.customer_display_names/1` accepting ids and returning names. A
team can keep that contract stable deliberately, review it deliberately, and
version it deliberately. A struct shape changes whenever somebody adds a
field.

### `calculate/3` gets the whole batch, which is why the interface takes a list

Ash calls `calculate/3` once with all the records being loaded. Loading
`:customer_display_name` over one order or a thousand makes exactly one call
into `Customers`. This matters because "you can't join a function call" is
the standard objection to replacing a relationship with a calculation: a
naive implementation calling the other domain once per record replaces one
query with N.

The fix shapes the exported interface around the caller's real access
pattern. `:display_names` takes a list because its caller is a calculation.
That decision lives on the `Customers` side, behind the interface.
`Customers` can switch to caching, batch differently, or use a different
storage strategy, and `Orders` never changes. A relationship would put that
decision in `Orders`' query.

## Alias checking is on by default

One detail underneath this example would otherwise be a trap.

`boundary` does not check plain alias references by default:
`check: [aliases: false]` is its documented default. It checks calls and
struct expansions.

```elixir
belongs_to :customer, OtherDomain.Customer
```

is neither: the other domain's resource module is named as a value, with
nothing called on it. Under `boundary`'s own defaults, a cross-domain
relationship, the single thing this example is about, is exactly the kind of
coupling that slips through. The `antipattern/` tree compiles clean under
those defaults: exit 0, no warning.

**AshBoundary enables alias checking for every domain it declares, so this
example's `mix.exs` configures nothing.** No app author has to know about
this, remember it, or copy it into their own app. That matters because the
failure mode of forgetting it is silence, not an error.

If your own `mix.exs` sets `boundary: [default: [check: [...]]]`, AshBoundary
merges its default into your settings. It does not replace them, so a
`check: [apps: [...]]` of your own keeps working. An explicit
`check: [aliases: false]` there is respected, on the assumption that anyone
who writes it means it.

Turning alias checking on only adds checks. The shipped state here, and
samples 1 and 2's demonstrated violations, stay unaffected: those are
function calls, and function calls are checked either way.

## Running it

```
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

Run `mix deps.get` before `mix format --check-formatted`. `.formatter.exs`'s
`import_deps` needs the deps present on disk to resolve. On a clean checkout,
skipping this order fails with
`Unknown dependency :ash given to :import_deps`. All four commands succeed.

`mix test` proves the AFTER state works end to end, with no mocks or stubs.
`DecouplingViaCalculation.OrdersTest` sits outside both domains' namespaces,
the position a real consumer holds. It registers customers through
`Customers.register_customer!/2`, places orders through
`Orders.place_order!/1`, and loads `:customer_display_name`. The asserted
names (`"Ada Lovelace"`, `"Grace Hopper"`) exist nowhere in `Orders`:
`Customer`'s `:display_name` calculation builds them from `first_name` and
`family_name` in the other domain's ETS table, and only the calculation
calling the exported function carries them to the assertion. The tests also
cover the batch case (three orders, two customers, one `Ash.load!`) and the
unknown-id case (the contract returns no entry, so the calculation resolves
to `nil`).

## Reproducing the BEFORE state yourself

The BEFORE state ships as real, complete code in `antipattern/`.
`elixirc_paths` in `mix.exs` keeps it out of every normal build, so this
example's own gate stays green. One command compiles it:

```
$ MIX_ENV=antipattern mix compile
Compiling 11 files (.ex)
Generated decoupling_via_calculation app

warning: forbidden reference to DecouplingViaCalculation.Antipattern.Customers.Customer
  (module DecouplingViaCalculation.Antipattern.Customers.Customer is not exported by its owner boundary DecouplingViaCalculation.Antipattern.Customers)
  antipattern/orders/order.ex:45
```

`antipattern/orders/order.ex:45` is the `belongs_to` line. As in samples 1
and 2, this is a **warning**, and `mix compile` still exits `0`. Add
`--warnings-as-errors` and the same three lines fail the build with exit `1`:

```
$ MIX_ENV=antipattern mix compile --warnings-as-errors
Compiling 11 files (.ex)
Generated decoupling_via_calculation app

warning: forbidden reference to DecouplingViaCalculation.Antipattern.Customers.Customer
  (module DecouplingViaCalculation.Antipattern.Customers.Customer is not exported by its owner boundary DecouplingViaCalculation.Antipattern.Customers)
  antipattern/orders/order.ex:45
```

`boundary` prints nothing further after the warning itself. No trailing
"Compilation failed" summary line follows this kind of warning. The exit code
is `1`, and `--warnings-as-errors` depends on that exit code to fail the
build.

Everything above is real output, captured from this example. Note that
`MIX_ENV=antipattern` builds into `_build/antipattern/`, so it cannot disturb
the shipped build's artifacts. The first run compiles the deps for that env,
which takes a minute.

The same failure can occur in the shipped example too, which sharpens the
point: the AFTER state is not a convention that could be quietly abandoned.
Add this to `lib/decoupling_via_calculation/orders/order.ex`:

```elixir
relationships do
  belongs_to :customer, DecouplingViaCalculation.Customers.Customer
end
```

`mix compile` then reports (the line number depends on where the block is
pasted; this capture places it immediately above `calculations do`):

```
warning: forbidden reference to DecouplingViaCalculation.Customers.Customer
  (module DecouplingViaCalculation.Customers.Customer is not exported by its owner boundary DecouplingViaCalculation.Customers)
  lib/decoupling_via_calculation/orders/order.ex:46
```

Delete those three lines to restore the example to its shipped state.

### The escape hatch, and why it is not one

A second way exists to make the BEFORE state compile. It matters to see it,
because it is what a hurried developer will actually do. In
`antipattern/customers.ex`, give `Customer` a domain-level `define`:

```elixir
resource DecouplingViaCalculation.Antipattern.Customers.Customer do
  define :get_customer, action: :read, get_by: [:id]
end
```

`MIX_ENV=antipattern mix compile --warnings-as-errors` now exits `0`. Not one
warning. This example must put the trade-off in front of you:

- One `define` exports the **whole `Customer` module** to the entire app.
  `boundary`'s exports work at module level, not function level (a limitation
  AshBoundary's docs call out and accept), so no option exports it just for
  the relationship.
- The relationship now compiles. Every cost listed under "BEFORE" above stays,
  in full. The build is green, and the domains stay entangled.
- `boundary` stops helping with `Customer` anywhere else: any module in the
  app may now reference it, load its relationships, and match on its struct.

Exporting a resource is often exactly right. Samples 1 and 2 do it, and a
domain whose consumers genuinely need to receive a record from a read action
and hand it back to an update action should export it. It is wrong when a
team does it to satisfy a relationship, paying a permanent, app-wide
encapsulation cost to keep a coupling nobody wanted to defend.

## Design note: the facade resource

`Customers` could have put its domain-level `define`s on `Customer` directly.
That is the more common Ash shape, and samples 1 and 2 use it. This example
uses a facade resource for one reason: a `define` on `Customer` exports the
`Customer` module, and then `belongs_to :customer, Customers.Customer`
compiles. The anti-pattern this example
teaches against would then compile in this example. The compiler would no
longer hold the AFTER state in place.

Keeping the interface on its own resource makes the exported surface equal to
the interface. `Customer` stays internal. The direct relationship stays a
compile error. "Minimal, intentional exports" becomes a fact about the
build.

The trade-off costs one extra module, and a slightly less familiar shape (a
resource with no data layer, existing only for its generic actions). This
example suggests a rule of thumb: when another domain needs an **answer**,
give it a purpose-built interface and keep the resource internal. When
another domain genuinely needs the **record**, export the resource with a
domain-level `define` and accept that its module is public. Reaching for a
relationship is the case where a team looks like it needs the record, when it
needed an answer.

## Gate

Run this from within this directory, same as every example in this series:

```
mix deps.get && mix format --check-formatted && mix compile --warnings-as-errors && mix test
```

`antipattern/` is format-checked (`.formatter.exs` lists it in `inputs`) but
this gate never compiles it, which is the whole reason the BEFORE state can
ship as real code. `MIX_ENV=antipattern mix compile` is expected to fail, so
it is not part of the gate: a green result there would mean the violation
went uncaught.

See `examples/01_basic_boundary/README.md`'s "Conventions for other examples"
section for the full set of structural conventions this example follows
(standalone Mix project, committed `mix.lock`, mandatory root `use Boundary`
module, and so on). They apply here without modification.
