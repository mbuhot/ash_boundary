# 02: Exported vs. internal

A single `Ash.Domain`, extended with `AshBoundary`, holding two resources that look
similarly "public" at a glance — both have *some* code interface generating callable
functions — but are exported completely differently. This is sample project 2 of 4
from the AshBoundary project goal, and its whole point is correcting the natural but
wrong assumption that "has a code interface" means "is exported."

`examples/01_basic_boundary` already showed one exported resource and one plain
resource with no code interface at all. That contrast is easy to get right by
accident. This example makes the actually subtle case sharp: a resource can have its
*own* `code_interface do define ... end` block — real, generated, callable
functions — and still be entirely internal, because **exported status comes from one
thing only: whether a domain-level `define` names that resource in the domain's
`resources` block.** A resource-level `code_interface` and a domain-level `define` are
independent DSL features that happen to both generate functions; only the second one
affects what `boundary` protects.

## What this shows

- `ExportedVsInternal.Catalog` (`lib/exported_vs_internal/catalog.ex`) is the
  `Ash.Domain`, extended with `AshBoundary`, exactly as in example 1.
- `ExportedVsInternal.Catalog.Product` (`lib/exported_vs_internal/catalog/product.ex`)
  carries a domain-level `define` in `Catalog`'s `resources` block
  (`define :create_product, ...` / `define :get_product, ...`), so `AshBoundary`
  computes it as **exported**, same as `BasicBoundary.Blog.Post` in example 1. Outside
  code calls it through the domain's own generated functions,
  `ExportedVsInternal.Catalog.create_product!/1` and `get_product!/1`.
- `ExportedVsInternal.Catalog.InternalPricing`
  (`lib/exported_vs_internal/catalog/internal_pricing.ex`) has a **bare** `resource`
  entry in `Catalog`'s `resources` block — no domain-level `define` — so `AshBoundary`
  leaves it out of `exports`. But the resource module itself declares its own
  `code_interface do define :record, ...; define :calculate, ... end`, which generates
  perfectly ordinary functions, `InternalPricing.record!/1` and
  `InternalPricing.calculate!/1`. Nothing about those functions is fake, disabled, or
  gated on their own — they're standard Ash code interface output, exactly like
  `Product`'s. `boundary` doesn't inspect *how* a function came to exist on a module;
  it only ever asks whether the *module* is exported by its owner boundary. Since
  `InternalPricing` isn't, calling either of its functions from outside
  `ExportedVsInternal.Catalog.*` is a forbidden reference — reproduced for real below —
  even though the exact same call from inside the domain works fine.
- `ExportedVsInternal.Catalog.InternalReports`
  (`lib/exported_vs_internal/catalog/internal_reports.ex`) lives *inside*
  `ExportedVsInternal.Catalog`'s own namespace and calls `InternalPricing.record!/1`
  then `InternalPricing.calculate!/1` directly. `boundary` classifies this module as
  part of the `ExportedVsInternal.Catalog` boundary (it nests under
  `ExportedVsInternal.Catalog.*`), so the call never crosses a boundary line and is
  never even a candidate for a violation — this is the "internal is still fully usable
  from the right place" half of the story.
- `ExportedVsInternal.Storefront` (`lib/exported_vs_internal/storefront.ex`) lives
  *outside* `ExportedVsInternal.Catalog`'s namespace and calls only the domain's
  exported interface (`Catalog.create_product!/1`, `Catalog.get_product!/1`) — the
  "exported is reachable from anywhere" half.
- `ExportedVsInternal` (`lib/exported_vs_internal.ex`) is the application's own root
  boundary, declared with plain `use Boundary` — mandatory for the same reason
  explained in example 1's README: `Catalog` only carves out its own subtree, and
  skipping a root claim silently disables the forbidden-reference check for whatever
  is left unclassified (here, `ExportedVsInternal.Storefront`).
- `mix.exs` adds `compilers: [:boundary] ++ Mix.compilers()`, same as every example.

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
succeed. `mix test` runs two tests, and together they *are* the proof this
example exists to give:

- `ExportedVsInternal.StorefrontTest` (outside `Catalog`'s namespace) creates a product
  and reads it back purely through the domain's exported interface.
- `ExportedVsInternal.Catalog.InternalReportsTest` (inside `Catalog`'s namespace) books
  a cost/margin pair and reads back its computed sale price purely through
  `InternalPricing`'s own resource-level code interface.

Both hit the real ETS data layer and both pass. The only difference between them is
*where the caller is allowed to stand* — not whether the callee works. That difference
only becomes visible to the compiler, not to `mix test`, which is what the next section
reproduces.

## Reproducing the violation yourself

Same convention as example 1: `boundary` reports a cross-boundary violation as a
compiler **warning**, not a hard failure, unless the build also passes
`--warnings-as-errors`, so this example doesn't ship a failing build. To see the
distinction enforced for yourself:

1. Add a module outside `ExportedVsInternal.Catalog`'s namespace that calls
   `InternalPricing`'s own code interface function directly — not the module itself,
   its *code interface*, to make the point precisely: a new file
   `lib/exported_vs_internal/scratch_violation.ex`:

   ```elixir
   defmodule ExportedVsInternal.ScratchViolation do
     alias ExportedVsInternal.Catalog.InternalPricing

     def run, do: InternalPricing.calculate!("sku-1")
   end
   ```

2. Run `mix compile`. It succeeds (exit code `0`) but prints:

   ```
   warning: forbidden reference to ExportedVsInternal.Catalog.InternalPricing
     (module ExportedVsInternal.Catalog.InternalPricing is not exported by its owner boundary ExportedVsInternal.Catalog)
     lib/exported_vs_internal/scratch_violation.ex:4
   ```

   Note what the warning does *not* say: it never mentions `calculate!/1`, `record!/1`,
   or "code interface" at all. `boundary` rejected the reference the moment it saw
   `ExportedVsInternal.Catalog.InternalPricing` used outside its owner boundary — the
   function being called, and the fact that Ash calls it a code interface, never enters
   into the check. This is the concrete proof that "has a code interface" and "is
   exported" are unrelated: the function exists, is real, and would return a real
   answer if this call were allowed to run — it just isn't allowed to run from here.

3. Run `mix compile --warnings-as-errors` next. No forced rebuild is needed first —
   `boundary`'s checks re-run on every invocation of the `:boundary` compiler. This
   exits `1`, the exact same warning, now treated as a build failure:

   ```
   $ mix compile --warnings-as-errors
   ...
   warning: forbidden reference to ExportedVsInternal.Catalog.InternalPricing
     (module ExportedVsInternal.Catalog.InternalPricing is not exported by its owner boundary ExportedVsInternal.Catalog)
     lib/exported_vs_internal/scratch_violation.ex:4
   ```

   `boundary` prints nothing further after the warning itself — there is no trailing
   "Compilation failed" summary line for this kind of warning (unlike some other
   warning types, which do log a separate summary). The exit code is `1`, which is what
   `--warnings-as-errors` actually depends on to fail the build.

4. Delete `lib/exported_vs_internal/scratch_violation.ex` to restore the example to its
   shipped state.

This is exactly the sequence used to verify this example while it was built — the
warning text above is real output, not a paraphrase, and no `InternalPricing` violation
actually ships in this example's own `lib/`.

## Gate

Same as every example in this series, run from within this directory:

```
mix deps.get && mix format --check-formatted && mix compile --warnings-as-errors && mix test
```

See `examples/01_basic_boundary/README.md`'s "Conventions for other examples" section
for the full set of structural conventions this example follows (standalone Mix
project, committed `mix.lock`, mandatory root `use Boundary` module, and so on) — they
apply here without modification.
