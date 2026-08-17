# 02: Exported vs. internal

Two Ash domains, both extended with `AshBoundary`. `Catalog` holds two resources, and both of
them have a code interface. `Catalog` exports one of them. `Storefront` is a second domain that
calls the exported one.

A domain-level `define` in the `resources` block exports a resource. A resource-level
`code_interface` block generates callable functions and has no effect on export status.
`boundary` checks module references, not function names.

## Modules

- `Catalog` (`lib/catalog.ex`) is the domain over `Catalog.*`.
- `Catalog.Product` has two domain-level `define`s in `Catalog`'s `resources` block, so
  AshBoundary exports it. Callers reach it through `Catalog.create_product!/1` and
  `Catalog.get_product!/1`.
- `Catalog.InternalPricing` has a bare `resource` entry with no domain-level `define`, so
  AshBoundary leaves it out of `exports`. The resource module declares its own `code_interface`,
  which generates `InternalPricing.record!/1` and `InternalPricing.calculate!/1`.
- `Catalog.InternalReports` sits inside `Catalog`'s namespace and calls both of those generated
  functions. That reference stays inside one boundary.
- `Storefront` (`lib/storefront.ex`) is the second domain. It declares `deps [Catalog]`, owns no
  resources, and calls `Catalog`'s exported interface.

The computed declarations:

```elixir
AshBoundary.Declaration.definition(Catalog).opts
#=> [exports: [Product], deps: [], check: [aliases: true]]

AshBoundary.Declaration.definition(Storefront).opts
#=> [exports: [], deps: [Catalog], check: [aliases: true]]
```

## Two top-level domains

`Catalog` and `Storefront` are top-level modules, which makes them siblings.
`Boundary.Checker.validate_dep_allowed/4` lets a boundary name a sibling, a parent, or a dep of
its parent, so `Storefront` can name `Catalog`. Drop the `deps [Catalog]` entry and
`Catalog.create_product!/1` becomes a forbidden reference too. The dep grants access to another
domain. The exports decide how far that access reaches.

Every module here falls under `Catalog.*` or `Storefront.*`, so this example needs no root
boundary. See
[`examples/04_phoenix_liveview`](../04_phoenix_liveview/README.md#why-the-domain-is-the-top-level-module)
for the other layouts that give a domain a sibling.

## The forbidden call

`lib/storefront.ex` carries the forbidden call as a comment, directly above the allowed one.
Uncomment it and `boundary` reports a forbidden reference to `Catalog.InternalPricing`. The
warning names the module and no function. The resource's working code interface does not change
the outcome.

## Tests

`mix test` runs two tests against the ETS data layer:

- `StorefrontTest` creates a product and reads it back through `Catalog`'s exported interface,
  across the domain line that `deps [Catalog]` opens.
- `Catalog.InternalReportsTest` books a cost/margin pair and reads back its computed sale price
  through `InternalPricing`'s own resource-level code interface, from inside `Catalog`.

## Gate

Run this from within this directory:

```
mix deps.get && mix format --check-formatted && mix compile --warnings-as-errors && mix test
```
