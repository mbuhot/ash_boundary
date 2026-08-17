# 03: Decoupling a cross-domain relationship into a calculation

Two Ash domains, a direct resource-to-resource relationship between them, and the
replacement for it: a calculation that calls the other domain's exported function. This is
sample project 3 of 4 from the AshBoundary project goal, and it is the pattern the whole
library exists to make visible and enforceable — samples 1 and 2 set up the vocabulary
(default enforcement, exported vs. internal), this one is what the vocabulary is *for*.

Both states are here:

- **BEFORE** — `antipattern/`, four files, a real Ash app with `Order belongs_to Customer`
  across a domain line. It does not compile under boundary enforcement, so it is
  deliberately excluded from every normal build (see `mix.exs`) and compiled only by
  `MIX_ENV=antipattern mix compile`, whose entire purpose is to fail. Reproduced verbatim
  below.
- **AFTER** — `lib/`, the shipped example. Compiles with `--warnings-as-errors`, and
  `mix test` proves the calculation returns real data from the other domain through real
  Ash actions against the ETS data layer.

## The two domains

| Module | Exported? | Role |
| --- | --- | --- |
| `DecouplingViaCalculation.Customers` | yes (a boundary's root always is) | domain that owns customer data |
| `DecouplingViaCalculation.Customers.Customer` | **no** | the real, ETS-backed resource. Attributes `first_name`/`family_name`, a `:display_name` calculation, its own `code_interface` for use inside the domain |
| `DecouplingViaCalculation.Customers.Directory` | yes | the domain's entire public API: two generic actions, `:register` and `:display_names` |
| `DecouplingViaCalculation.Orders` | yes | domain that owns orders. `boundary do deps [...Customers] end` |
| `DecouplingViaCalculation.Orders.Order` | yes | has `attribute :customer_id, :uuid` — no relationship — and the `:customer_display_name` calculation |
| `DecouplingViaCalculation.Orders.Calculations.CustomerDisplayName` | no (internal to `Orders`) | the calculation module. The only code in `Orders` that mentions `Customers` at all |
| `DecouplingViaCalculation` | — | the app's root boundary, plain `use Boundary`, mandatory in every example (see sample 1) |

The computed declarations, read back off the compiled modules with
`AshBoundary.Declaration.definition/1`:

```
DecouplingViaCalculation:           []
DecouplingViaCalculation.Customers: [exports: [Directory], deps: []]
DecouplingViaCalculation.Orders:    [exports: [Order], deps: [DecouplingViaCalculation.Customers]]
```

`Customers` exports exactly one module, and it is not `Customer`.

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

This is the natural thing to write, and nothing about it is stupid — it is *correct Ash*.
What it costs is not visible in the diff that adds it:

- **`Orders` cannot be compiled, or understood, without `Customers`.** The resource module
  of another domain is named here at compile time.
- **`Orders` now queries another domain's storage.** `load: [:customer]` is a read issued
  against customer data by order code. `Customer` can no longer change data layer, move
  behind a service call, or add a required filter/preparation to its reads without
  breaking a query that lives in `Orders`.
- **`Orders` now receives whole `Customer` structs**, and so does everything downstream of
  an order. Every customer attribute is in reach of code that had no business seeing it,
  and any of it may quietly become load-bearing. Renaming `family_name` stops being a
  local change.
- **The entanglement is mutual and grows.** The natural next step is
  `has_many :orders, ...Orders.Order` on `Customer` — the same violation in the other
  direction, this time from a domain that declared no `deps` at all. At that point the two
  domains are one domain with two names.

Note that the BEFORE domain does *not* cheat: `antipattern/orders.ex` declares the
dependency honestly, in exactly the line AshBoundary asks for.

```elixir
boundary do
  deps [DecouplingViaCalculation.Antipattern.Customers]
end
```

That is necessary and not sufficient, which is the point of the whole exercise: a `deps`
entry grants access to what the other boundary **exports**, and `Customer` is not
exported. See "Reproducing the BEFORE state yourself" below for the compiler refusing it.

## AFTER: an id, plus a calculation over an exported function

Three changes, and they are the entire pattern.

**1. The relationship becomes a plain id.** `lib/decoupling_via_calculation/orders/order.ex`:

```elixir
attribute :customer_id, :uuid, allow_nil?: false, public?: true
```

An order records *which* customer placed it. It holds no module reference, no expectation
about that module's attributes, and no ability to load anything from it.

**2. `Customers` exports a purpose-built interface** —
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

`Directory` is a resource with no data layer and no attributes, holding two generic
actions over the internal `Customer`. `:register` returns an **id**, not a record.
`:display_names` takes a **list of ids** and returns `%{id => "Ada Lovelace"}`. Callers get
answers; they never get a `Customer`.

**3. `Order` gains a calculation that calls that interface** —
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

Declared on the resource as an ordinary calculation, loadable like any other:

```elixir
calculate :customer_display_name, :string, CustomerDisplayName do
  public? true
end

# ...
Orders.get_order!(order.id, load: [:customer_display_name]).customer_display_name
#=> "Ada Lovelace"
```

What crosses the boundary is one function call: a list of ids in, a map of strings out.
What does **not** cross it:

- `DecouplingViaCalculation.Customers.Customer` — never referenced by `Orders`, and not
  exported, so it *cannot* be referenced even by accident. The compiler enforces this, and
  the "Reproducing" section below shows it refusing exactly that.
- Customer attribute names. `first_name` and `family_name` appear nowhere in `Orders`.
  Splitting the name differently, renaming a field, or changing what a display name means
  is a local change inside `Customers`, invisible to `Orders`, as long as
  `customer_display_names/1` still answers the same question.
- Customer's data layer, actions, filters and preparations. `Orders` issues no query
  against customer data; it asks a question through a function.

The dependency that remains is a *contract*: `Orders` depends on
`Customers.customer_display_names/1` accepting ids and returning names. That is a thing
you can keep stable deliberately, review deliberately, and version deliberately — unlike a
struct shape, which changes whenever somebody adds a field.

### `calculate/3` gets the whole batch, which is why the interface takes a list

Ash calls `calculate/3` once with *all* the records being loaded, so loading
`:customer_display_name` over one order or a thousand makes exactly one call into
`Customers`. This matters because "you can't join a function call" is the standard and fair
objection to replacing a relationship with a calculation: a naive implementation calling
the other domain once per record replaces one query with N.

The fix is to shape the *exported* interface around the caller's real access pattern —
`:display_names` takes a list because its caller is a calculation. And note where that
decision lives: on the `Customers` side, behind the interface. `Customers` can switch to
caching, batching differently, or a completely different storage strategy without `Orders`
changing at all. A relationship would have put that decision in `Orders`' query.

## Alias checking is on by default

There is a detail underneath this whole example that would otherwise be a trap.

`boundary` does not check plain *alias references* by default — `check: [aliases: false]`
is its documented default. It checks calls and struct expansions, and

```elixir
belongs_to :customer, OtherDomain.Customer
```

is neither: the other domain's resource module is named as a value, with nothing called on
it. So under `boundary`'s own defaults, a cross-domain relationship — the single thing
this example is about — is exactly the kind of coupling that slips through. This was
observed here first-hand: the `antipattern/` tree compiled clean, exit 0, no warning.

**AshBoundary enables alias checking for every domain it declares, so this example's
`mix.exs` configures nothing.** It is not something you have to know about, remember, or
copy into your own app — which is the point, because the failure mode of forgetting it is
silence, not an error.

If you *do* set `boundary: [default: [check: [...]]]` in your own `mix.exs`, AshBoundary
merges its default into your settings rather than replacing them, so a
`check: [apps: [...]]` of your own keeps working. An explicit
`check: [aliases: false]` there is respected, on the assumption that anyone writing it
means it.

Turning alias checking on only *adds* checks: the shipped state here, and samples 1 and 2's
demonstrated violations, are unaffected (those are function calls, which are checked either
way).

## Running it

```
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

`mix deps.get` must run before `mix format --check-formatted`: `.formatter.exs`'s
`import_deps` needs the deps actually present on disk to resolve, and fails with
`Unknown dependency :ash given to :import_deps` on a clean checkout otherwise. All four
succeed.

`mix test` is the proof that the AFTER state genuinely works, end to end, with no mocks or
stubs anywhere. `DecouplingViaCalculation.OrdersTest` sits outside both domains'
namespaces — the position a real consumer is in — registers customers through
`Customers.register_customer!/2`, places orders through `Orders.place_order!/1`, and loads
`:customer_display_name`. The names it asserts on (`"Ada Lovelace"`, `"Grace Hopper"`) exist
nowhere in `Orders`: they are built by `Customer`'s `:display_name` calculation from
`first_name` and `family_name` in the other domain's ETS table, and the only way they can
reach the assertion is through the calculation calling the exported function. The tests also
cover the batch case (three orders, two customers, one `Ash.load!`) and the unknown-id case
(the contract returns no entry, so the calculation resolves to `nil`).

## Reproducing the BEFORE state yourself

The BEFORE state ships as real, complete code in `antipattern/`, kept out of every normal
build by `elixirc_paths` in `mix.exs` so that this example's own gate stays green. One
command compiles it:

```
$ MIX_ENV=antipattern mix compile
Compiling 11 files (.ex)
Generated decoupling_via_calculation app

warning: forbidden reference to DecouplingViaCalculation.Antipattern.Customers.Customer
  (module DecouplingViaCalculation.Antipattern.Customers.Customer is not exported by its owner boundary DecouplingViaCalculation.Antipattern.Customers)
  antipattern/orders/order.ex:46
```

`antipattern/orders/order.ex:46` is the `belongs_to` line. As in samples 1 and 2, this is a
**warning** and `mix compile` still exits `0`; add `--warnings-as-errors` and the same
three lines fail the build with exit `1`:

```
$ MIX_ENV=antipattern mix compile --warnings-as-errors
Compiling 11 files (.ex)
Generated decoupling_via_calculation app

warning: forbidden reference to DecouplingViaCalculation.Antipattern.Customers.Customer
  (module DecouplingViaCalculation.Antipattern.Customers.Customer is not exported by its owner boundary DecouplingViaCalculation.Antipattern.Customers)
  antipattern/orders/order.ex:46
```

`boundary` prints nothing further after the warning itself — there is no trailing
"Compilation failed" summary line for this kind of warning. The exit code is `1`, which is
what `--warnings-as-errors` actually depends on to fail the build.

Everything above is real output, captured from this example, not a paraphrase. Note that
`MIX_ENV=antipattern` builds into `_build/antipattern/`, so it cannot disturb the shipped
build's artifacts; the first run compiles the deps for that env, which takes a minute.

The same failure can be produced in the *shipped* example, which is the sharper version of
the point — the AFTER state is not a convention that could be quietly abandoned. Add to
`lib/decoupling_via_calculation/orders/order.ex`:

```elixir
relationships do
  belongs_to :customer, DecouplingViaCalculation.Customers.Customer
end
```

and `mix compile` reports (the line number depends on where the block is pasted; this was
captured with it immediately above `calculations do`):

```
warning: forbidden reference to DecouplingViaCalculation.Customers.Customer
  (module DecouplingViaCalculation.Customers.Customer is not exported by its owner boundary DecouplingViaCalculation.Customers)
  lib/decoupling_via_calculation/orders/order.ex:46
```

Delete those three lines to restore the example to its shipped state.

### The escape hatch, and why it is not one

There is a second way to make the BEFORE state compile, and it is important to see it,
because it is what a hurried developer will actually do. In `antipattern/customers.ex`,
give `Customer` a domain-level `define`:

```elixir
resource DecouplingViaCalculation.Antipattern.Customers.Customer do
  define :get_customer, action: :read, get_by: [:id]
end
```

`MIX_ENV=antipattern mix compile --warnings-as-errors` now exits `0`. Not one warning. That
was verified, not assumed — and it is the honest trade-off this example has to put in front
of you rather than assert:

- One `define` exports the **whole `Customer` module** to the entire app. `boundary`'s
  exports are module-level, not function-level (a limitation AshBoundary's docs call out
  and accept), so there is no "export it just for the relationship".
- The relationship now compiles, so every cost listed under "BEFORE" above is still there,
  in full — only nobody is being told about it any more. The build is green and the
  domains are entangled.
- And `boundary` has stopped helping with `Customer` *anywhere else*: any module in the app
  may now reference it, load its relationships, and match on its struct.

Exporting a resource is often exactly right — samples 1 and 2 do it, and a domain whose
consumers genuinely need to receive a record from a read action and hand it back to an
update action should export it. It is wrong when it is done *to satisfy a relationship*,
because that is paying a permanent, app-wide encapsulation cost to keep a coupling nobody
wanted to defend.

## Design note: why a facade resource rather than `define`s on `Customer`

`Customers` could have put its domain-level `define`s on `Customer` directly. That is the
more common Ash shape, and it is what samples 1 and 2 do. It was not used here, for one
reason: a `define` on `Customer` exports the `Customer` module, and then
`belongs_to :customer, Customers.Customer` compiles — the anti-pattern this example teaches
against becomes legal in the very example that teaches against it, and the AFTER state
would be a style preference rather than something the compiler holds in place.

Keeping the interface on its own resource makes the exported surface *equal* to the
interface. `Customer` stays internal; the direct relationship stays a compile error;
"minimal, intentional exports" is a fact about the build rather than a claim in a README.

The trade-off is one extra module, and a slightly less familiar shape (a resource with no
data layer, existing only for its generic actions). The rule of thumb this example suggests:
when another domain needs an **answer**, give it a purpose-built interface and keep the
resource internal; when another domain genuinely needs the **record**, export the resource
with a domain-level `define` and accept that its module is public. Reaching for a
relationship is the case where it looks like you need the record but you needed an answer.

## Gate

Same as every example in this series, run from within this directory:

```
mix deps.get && mix format --check-formatted && mix compile --warnings-as-errors && mix test
```

`antipattern/` is format-checked (it is listed in `.formatter.exs` inputs) but never
compiled by this gate, which is the whole reason the BEFORE state can ship as real code.
`MIX_ENV=antipattern mix compile` is *expected* to fail and is therefore not part of the
gate — a green result there would mean the violation was not caught.

See `examples/01_basic_boundary/README.md`'s "Conventions for other examples" section for
the full set of structural conventions this example follows (standalone Mix project,
committed `mix.lock`, mandatory root `use Boundary` module, and so on) — they apply here
without modification.
