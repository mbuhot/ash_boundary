# 01: Basic boundary setup

The smallest possible `AshBoundary` setup: one `Ash.Domain`, extended with
`AshBoundary`, with no `boundary do ... end` section at all — showing that
"do nothing extra" is already the strictest and most useful default.

This is sample project 1 of 4 from the AshBoundary project goal. It exists to show
*default enforcement on a single domain*. Cross-domain `deps`, the
exported-vs-internal side-by-side, the calculation-based decoupling pattern, and a
dedicated violation-catching demo each get their own example (`02_...` through
`04_...`) rather than being crammed in here — see "Conventions for other examples"
below.

## What this shows

- `BasicBoundary.Blog` (`lib/basic_boundary/blog.ex`) is an `Ash.Domain` extended with
  `extensions: [AshBoundary]`. It writes no `boundary` section, because a domain with
  none still gets `deps: []`, which is already what most domains want.
- `BasicBoundary.Blog.Post` (`lib/basic_boundary/blog/post.ex`) has a domain-level
  `define` in `Blog`'s `resources` block, so `AshBoundary` computes it as **exported**.
- `BasicBoundary.Blog.Comment` (`lib/basic_boundary/blog/comment.ex`) has no
  domain-level `define`, so it stays **internal** — the default for every resource,
  unless a domain-level `define` says otherwise.
- `BasicBoundary.Reports` (`lib/basic_boundary/reports.ex`) lives entirely outside
  `BasicBoundary.Blog`'s namespace and calls it only through its exported code
  interface (`BasicBoundary.Blog.create_post!/1`, `BasicBoundary.Blog.get_post!/1`).
  `test/basic_boundary/reports_test.exs` actually runs this — creates a post and reads
  it back — so the happy path is proven by execution, not just by the fact that it
  compiles.
- `BasicBoundary` (`lib/basic_boundary.ex`) is the application's own root boundary,
  declared with plain `use Boundary` (not `AshBoundary` — it isn't an `Ash.Domain`).
  `boundary` expects every module in the app to be classified into *some* boundary,
  and `BasicBoundary.Blog` only carves out its own subtree; something still has to
  claim the rest (here, just `BasicBoundary.Reports`). Any real app adopting
  `boundary`, with or without `AshBoundary`, needs a boundary like this at its root —
  it is not an AshBoundary-specific concern, but its absence produces a confusing
  "not included in any boundary" warning with no obvious connection to the missing
  declaration, so it's included here rather than left as a surprise.
- `mix.exs` adds `compilers: [:boundary] ++ Mix.compilers()`. This is the one manual
  step `AshBoundary`'s moduledoc calls out: a dependency cannot add itself to your
  `:compilers` list, so every consuming app has to add this line itself. Miss it and
  everything above still compiles and installs correctly, with zero errors and zero
  violations ever reported.

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
should succeed. `mix test` runs `BasicBoundary.ReportsTest`, which is the
proof that calling the domain's exported interface from outside its namespace
genuinely works at runtime, not just at compile time.

## Reproducing the violation yourself

`boundary` reports a cross-boundary violation as a **compiler warning**, not a hard
failure, unless the build also passes `--warnings-as-errors` — this example doesn't
ship a failing build (a green `mix test` and `mix compile --warnings-as-errors` is the
whole point of every example in this series; the dedicated demonstration of a
violation actually failing a build is sample project 4). To see the enforcement for
yourself:

1. Add a module outside `BasicBoundary.Blog`'s namespace that references the internal
   `Comment` resource directly, for example a new file
   `lib/basic_boundary/scratch_violation.ex`:

   ```elixir
   defmodule BasicBoundary.ScratchViolation do
     def run, do: BasicBoundary.Blog.Comment.__info__(:module)
   end
   ```

2. Run `mix compile`. It succeeds (exit code `0`) but prints:

   ```
   warning: forbidden reference to BasicBoundary.Blog.Comment
     (module BasicBoundary.Blog.Comment is not exported by its owner boundary BasicBoundary.Blog)
     lib/basic_boundary/scratch_violation.ex:2
   ```

3. Run `mix compile --warnings-as-errors` next. No `rm -rf _build` or other forced
   rebuild is needed first — `boundary`'s checks re-run and re-report on every
   invocation of the `:boundary` compiler, not only when something was recompiled.
   This exits `1` — the exact same warning, just now treated as a build failure:

   ```
   $ mix compile --warnings-as-errors
   ...
   warning: forbidden reference to BasicBoundary.Blog.Comment
     (module BasicBoundary.Blog.Comment is not exported by its owner boundary BasicBoundary.Blog)
     lib/basic_boundary/scratch_violation.ex:2
   ```

   `boundary` prints nothing further after the warning itself — there is no trailing
   "Compilation failed" summary line for this kind of warning (unlike some other
   warning types, which do log a separate summary). The exit code is `1`, which is what
   `--warnings-as-errors` actually depends on to fail the build.

4. Delete `lib/basic_boundary/scratch_violation.ex` to restore the example to its
   shipped state.

This is exactly the sequence used to verify this example while it was built — the
warning text above is real output, not a paraphrase, and no `Comment` violation
actually ships in this example's own `lib/`.

## Conventions for other examples (02–04)

This is the first of four sample projects, so it sets the shared shape the rest
follow:

- **Directory**: `examples/NN_short_name/`, two-digit prefix, `snake_case` name.
- **Standalone Mix project**: its own `mix.exs`, `lib/`, `test/`, `.formatter.exs`, and
  `config/config.exs` — never sharing the root repo's `_build`/`deps`. Depends on
  `{:ash_boundary, path: "../.."}` plus whatever else that example specifically needs
  (e.g. `:ash`). Uses `Ash.DataLayer.Ets` for any resources, so no external database
  is ever needed to run an example. Its `mix.lock` **is committed**, the same as the
  root project's — do not add it to any `.gitignore`; an example is meant to build
  reproducibly, not re-resolve dependency versions on every checkout.
- **`compilers: [:boundary] ++ Mix.compilers()`** in every example's `mix.exs`,
  without exception — it's the one manual step this whole library requires of a real
  consumer, so every example demonstrates it being present, concretely, not just
  described in prose.
- **A plain root-level `use Boundary` module is mandatory in every example**, not
  optional polish — see `lib/basic_boundary.ex` here. `boundary` requires every module
  in the app to be classified into some boundary; a domain extended with `AshBoundary`
  only carves out its own namespace, so anything else in the example (any module not
  under a domain's namespace) needs a boundary of its own to belong to, and the
  simplest correct choice is one plain `use Boundary` module at the application's own
  root, claiming everything not already carved out. **Skipping this does not fail
  loudly**: an unclassified module produces only a "not included in any boundary"
  warning, and — this is the important part — the forbidden-reference check never
  fires for references *from* that module at all, silently disabling violation
  detection for it. A project that gives its non-domain code its own boundary instead
  of using the app-root module (for instance, wrapping just the one caller module in
  its own `use Boundary`) has the same silent gap unless that boundary also correctly
  declares every dependency it needs — the root-claiming-the-rest structure is the one
  that was actually verified to make the forbidden-reference check fire, so follow it
  rather than an apparently-equivalent alternative. This is the single most
  non-obvious structural requirement in this whole example; sample project 4 in
  particular, whose entire point is a caught violation, must get this right or its
  "demonstration" will silently prove nothing.
- **The root repo's `.gitignore`** ignores `examples/*/_build/`, `examples/*/deps/`,
  and `examples/*/doc/` in one place, rather than each example shipping its own
  `.gitignore` with the same three lines.
- **Proving the point**: an example's *happy path* (whatever it's specifically
  demonstrating works) is proven by a real `mix test` in that example's own project —
  never just "trust me, it compiles." An example whose whole point is a *violation
  being caught* is the exception: since `boundary` reports violations as warnings by
  default, catching one as a hard failure needs `--warnings-as-errors`, which is a
  distinct invocation from `mix test`. This example's convention is to demonstrate
  that as a documented, reproducible README walkthrough (as above) rather than
  shipping a build that's expected to fail — a shipped-and-failing build cannot be
  the thing `mix test`/CI runs and calls green. Sample project 4, whose entire reason
  to exist is a caught violation, is expected to need its own approach to make that
  automated (for example, a fixture excluded from normal `elixirc_paths` that a
  dedicated test compiles on demand and asserts fails) — pick whichever of the two
  approaches best suits what that example demonstrates, and document the choice
  there.
- **Gate**: every example must independently pass, from within its own directory:
  `mix deps.get && mix format --check-formatted && mix compile --warnings-as-errors
  && mix test`, in that order — `mix deps.get` has to run first, because
  `.formatter.exs`'s `import_deps` needs the deps actually present on disk to resolve
  and fails with `Unknown dependency :ash given to :import_deps` on a clean checkout
  otherwise. The format check is included explicitly because the root project's
  `.formatter.exs` does not reach into `examples/` at all — nothing else format-checks
  an example's code, so each example is responsible for passing this on its own. This
  is a new gate introduced by this example; the root repo's task-10 CI wiring is
  expected to loop over `examples/*/` and run exactly this for each one it finds — a
  project whose point is a caught violation still needs this to pass overall (see
  above: the violation itself is demonstrated without making the shipped build red).
