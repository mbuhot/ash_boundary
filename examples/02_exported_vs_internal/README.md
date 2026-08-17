# 02: Exported vs. internal

This example shows an `Ash.Domain` extended with `AshBoundary`. The domain holds two resources.
Both resources have a code interface. `AshBoundary` exports only one of them.

A domain-level `define` exports a resource. A resource-level `code_interface` generates callable
functions. A resource-level `code_interface` has no effect on export status. `boundary` checks
module references only. It does not check function names or the origin of a function.

## What this shows

- `ExportedVsInternal.Catalog` (`lib/exported_vs_internal/catalog.ex`) is the `Ash.Domain`,
  extended with `AshBoundary`, as in example 1.
- `ExportedVsInternal.Catalog.Product` (`lib/exported_vs_internal/catalog/product.ex`) has a
  domain-level `define` in `Catalog`'s `resources` block (`define :create_product, ...` and
  `define :get_product, ...`). `AshBoundary` marks `Product` as exported. Outside code calls it
  through `ExportedVsInternal.Catalog.create_product!/1` and `get_product!/1`.
- `ExportedVsInternal.Catalog.InternalPricing`
  (`lib/exported_vs_internal/catalog/internal_pricing.ex`) has a bare `resource` entry in
  `Catalog`'s `resources` block. This entry has no domain-level `define`. `AshBoundary` leaves
  `InternalPricing` out of `exports`.
  The resource module declares its own `code_interface do define :record, ...; define :calculate,
  ... end`. This block generates ordinary functions, `InternalPricing.record!/1` and
  `InternalPricing.calculate!/1`. These functions work the same as `Product`'s functions.
  `boundary` checks only whether the module is exported by its owner boundary. `InternalPricing`
  is not exported. A call to either function from outside `ExportedVsInternal.Catalog.*` is a
  forbidden reference. The walkthrough below reproduces this violation. The same call from inside
  the domain works.
- `ExportedVsInternal.Catalog.InternalReports`
  (`lib/exported_vs_internal/catalog/internal_reports.ex`) sits inside
  `ExportedVsInternal.Catalog`'s own namespace. It calls `InternalPricing.record!/1` and then
  `InternalPricing.calculate!/1` directly. `boundary` classifies `InternalReports` as part of the
  `ExportedVsInternal.Catalog` boundary, because it nests under `ExportedVsInternal.Catalog.*`.
  The call stays inside one boundary, so it is never a candidate for a violation.
- `ExportedVsInternal.Storefront` (`lib/exported_vs_internal/storefront.ex`) sits outside
  `ExportedVsInternal.Catalog`'s namespace. It calls only the domain's exported interface
  (`Catalog.create_product!/1`, `Catalog.get_product!/1`).
- `ExportedVsInternal` (`lib/exported_vs_internal.ex`) is the application's own root boundary. It
  uses plain `use Boundary`. This declaration is mandatory for the reason given in example 1's
  README: `Catalog` claims only its own subtree. A build with no root claim disables the
  forbidden-reference check for every unclassified module, here `ExportedVsInternal.Storefront`.
- `mix.exs` adds `compilers: [:boundary] ++ Mix.compilers()`, as in every example.

## Running it

```
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

Run `mix deps.get` before `mix format --check-formatted`. `.formatter.exs`'s `import_deps` needs
the deps on disk to resolve. Without this order, the command fails with `Unknown dependency :ash
given to :import_deps` on a clean checkout. All four commands succeed.

`mix test` runs two tests:

- `ExportedVsInternal.StorefrontTest` (outside `Catalog`'s namespace) creates a product and reads
  it back through the domain's exported interface.
- `ExportedVsInternal.Catalog.InternalReportsTest` (inside `Catalog`'s namespace) books a
  cost/margin pair and reads back its computed sale price through `InternalPricing`'s own
  resource-level code interface.

Both tests hit the real ETS data layer. Both tests pass. The compiler, not `mix test`, enforces
where a caller may stand. The next section reproduces that check.

## Reproducing the violation yourself

`boundary` reports a cross-boundary violation as a compiler warning, not a hard failure, unless
the build also passes `--warnings-as-errors`. This example does not ship a failing build. Follow
these steps to reproduce the violation:

1. Add a module outside `ExportedVsInternal.Catalog`'s namespace. This module calls
   `InternalPricing`'s own code interface function directly, to show a violation of the code
   interface itself. Create `lib/exported_vs_internal/scratch_violation.ex`:

   ```elixir
   defmodule ExportedVsInternal.ScratchViolation do
     alias ExportedVsInternal.Catalog.InternalPricing

     def run, do: InternalPricing.calculate!("sku-1")
   end
   ```

2. Run `mix compile`. The build succeeds (exit code `0`) and prints:

   ```
   warning: forbidden reference to ExportedVsInternal.Catalog.InternalPricing
     (module ExportedVsInternal.Catalog.InternalPricing is not exported by its owner boundary ExportedVsInternal.Catalog)
     lib/exported_vs_internal/scratch_violation.ex:4
   ```

   The warning names no function. It names no code interface. `boundary` rejected the reference
   as soon as it saw `ExportedVsInternal.Catalog.InternalPricing` used outside its owner boundary.
   The function called, and the fact that Ash generated it as a code interface, play no part in
   the check. The function exists. The function is real. The function would return a real answer
   if the call were allowed. The call is not allowed from this location.

3. Run `mix compile --warnings-as-errors` next. No rebuild step is needed first: `boundary`'s
   checks re-run on every invocation of the `:boundary` compiler. This command exits `1`, with the
   same warning, now treated as a build failure:

   ```
   $ mix compile --warnings-as-errors
   ...
   warning: forbidden reference to ExportedVsInternal.Catalog.InternalPricing
     (module ExportedVsInternal.Catalog.InternalPricing is not exported by its owner boundary ExportedVsInternal.Catalog)
     lib/exported_vs_internal/scratch_violation.ex:4
   ```

   `boundary` prints no summary line after this warning. The exit code `1` is what
   `--warnings-as-errors` depends on to fail the build.

4. Delete `lib/exported_vs_internal/scratch_violation.ex` to restore the example to its shipped
   state.

## Gate

Run this from within this directory:

```
mix deps.get && mix format --check-formatted && mix compile --warnings-as-errors && mix test
```

See `examples/01_basic_boundary/README.md`'s "Conventions for other examples" section for the
full set of structural conventions this example follows.
