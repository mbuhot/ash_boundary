# 01: Exported vs. internal

Two Ash domains under one app namespace, both extended with `AshBoundary`. `Catalog` holds two
resources and exports one of them. `Storefront` declares `deps [ExportedVsInternal.Catalog]`, owns
a resource of its own, and reaches catalog data through `Catalog`'s exported interface.

A domain-level `define` in the `resources` block exports a resource. A resource-level
`code_interface` block generates callable functions and has no effect on export status.
`boundary` checks module references, not function names.

## Modules

- `ExportedVsInternal.Catalog` (`lib/exported_vs_internal/catalog.ex`) is the domain over
  `ExportedVsInternal.Catalog.*`.
- `Catalog.Product` has three domain-level `define`s, so AshBoundary exports it. Callers reach it
  through `Catalog.create_product!/1`, `Catalog.get_product!/1`, `Catalog.price_product!/3` and
  `Catalog.product_sale_prices!/1`. The last two are generic actions that answer questions about
  pricing without returning a pricing record.
- `Catalog.InternalPricing` has a bare `resource` entry with no domain-level `define`, so
  AshBoundary leaves it out of `exports`. It holds `product_id`, `cost` and `margin`, plus a
  `:sale_price` calculation. Its own `code_interface` generates `InternalPricing.record!/1`,
  `InternalPricing.calculate!/1` and `InternalPricing.for_products!/1`.
- `Catalog.InternalReports` sits inside `Catalog`'s namespace and calls those generated
  functions. That reference stays inside one boundary.
- `ExportedVsInternal.Storefront` (`lib/exported_vs_internal/storefront.ex`) is the second
  domain. It exports `Storefront.Listing`.
- `Storefront.Listing` holds `attribute :product_id, :uuid` and no relationship, plus a
  `:sale_price` calculation.
- `Storefront.Calculations.SalePrice` is the calculation module, internal to `Storefront`. It is
  the only module in `Storefront` that mentions `Catalog` for listing data.

The computed declarations:

```elixir
AshBoundary.Declaration.definition(ExportedVsInternal.Catalog).opts
#=> [exports: [Product], deps: [], check: [aliases: true], top_level?: true]

AshBoundary.Declaration.definition(ExportedVsInternal.Storefront).opts
#=> [exports: [Listing], deps: [ExportedVsInternal.Catalog], check: [aliases: true], top_level?: true]
```

AshBoundary declares every domain `top_level?: true`, so the two domains are siblings even though
both sit under `ExportedVsInternal`. `Boundary.Checker.validate_dep_allowed/4` lets a boundary
name a sibling, so `Storefront` can name `Catalog`. Drop the `deps [ExportedVsInternal.Catalog]`
entry and `Catalog.create_product!/1` becomes a forbidden reference too. The dep grants access to
another domain. The exports decide how far that access reaches.

Every module here falls under `ExportedVsInternal.Catalog.*` or `ExportedVsInternal.Storefront.*`,
so this example needs no root boundary.

## An id and a calculation, not a relationship

`Listing` records which product it advertises as a plain `:uuid`. The `:sale_price` calculation
answers what that product sells for:

```elixir
def calculate(listings, _opts, _context) do
  product_ids = Enum.map(listings, & &1.product_id)
  prices = Catalog.product_sale_prices!(product_ids)

  {:ok, Enum.map(listings, &Map.get(prices, &1.product_id))}
end
```

Ash calls `calculate/3` once with the whole batch, and `Catalog.product_sale_prices!/1` takes a
list of ids and returns `%{product_id => sale_price}`. Loading `:sale_price` over one listing or a
thousand makes one call into `Catalog`.

`Storefront` names no resource module of `Catalog`'s, issues no query against catalog storage, and
never receives a pricing record. `Catalog` can change how a sale price is computed or stored while
`product_sale_prices/1` keeps answering the same question.

## The forbidden references

Two are carried as comments beside the code that replaced them:

- `lib/exported_vs_internal/storefront/listing.ex` names the `belongs_to` that
  `attribute :product_id, :uuid` replaces. Written as a relationship, it is a forbidden reference
  to `ExportedVsInternal.Catalog.InternalPricing`. AshBoundary sets `check: [aliases: true]`,
  which is what makes a cross-domain relationship a caught reference rather than a silent one.
- `lib/exported_vs_internal/storefront/calculations/sale_price.ex` carries a per-record call into
  `InternalPricing`, directly above the allowed batched one. Uncomment it and `boundary` reports
  the same forbidden reference. The warning names the module and no function. The resource's
  working code interface does not change the outcome.

## Tests

`mix test` runs five tests against the ETS data layer:

- `ExportedVsInternal.StorefrontTest` creates and reads a product through `Catalog`'s exported
  interface, then loads `:sale_price` for one listing, for a batch of three listings over two
  products, and for a product with no pricing recorded.
- `ExportedVsInternal.Catalog.InternalReportsTest` books a cost/margin pair and reads back its
  computed sale price through `InternalPricing`'s own resource-level code interface, from inside
  `Catalog`.

## Gate

Run this from within this directory:

```
mix deps.get && mix format --check-formatted && mix compile --warnings-as-errors && mix test
```
