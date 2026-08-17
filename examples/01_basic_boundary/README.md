# 01: Basic boundary setup

This example shows the smallest `AshBoundary` setup. It has one `Ash.Domain`,
extended with `AshBoundary`, with no `boundary do ... end` section.

A domain with no `boundary` section still gets `deps: []`. This is the strictest
and most useful default.

Examples 02 through 05 cover an exported-vs-internal comparison, the
calculation-based decoupling pattern, a dedicated violation-catching demo, and a
Phoenix LiveView web layer that cannot call `Ash.*` directly. See "Conventions
for other examples" below.

## What this shows

- `BasicBoundary.Blog` (`lib/basic_boundary/blog.ex`) is an `Ash.Domain` with
  `extensions: [AshBoundary]`. It has no `boundary` section. A domain with no
  section still gets `deps: []`.
- `BasicBoundary.Blog.Post` (`lib/basic_boundary/blog/post.ex`) has a
  domain-level `define` in `Blog`'s `resources` block. `AshBoundary` computes it
  as exported.
- `BasicBoundary.Blog.Comment` (`lib/basic_boundary/blog/comment.ex`) has no
  domain-level `define`. It stays internal. Every resource is internal by
  default, unless a domain-level `define` names it as exported.
- `BasicBoundary.Reports` (`lib/basic_boundary/reports.ex`) lives outside
  `BasicBoundary.Blog`'s namespace. It calls the domain only through its
  exported code interface: `BasicBoundary.Blog.create_post!/1` and
  `BasicBoundary.Blog.get_post!/1`. `test/basic_boundary/reports_test.exs` runs
  this code: it creates a post and reads it back.
- `BasicBoundary` (`lib/basic_boundary.ex`) is the application's own root
  boundary. It uses plain `use Boundary`, not `AshBoundary`, because it is not
  an `Ash.Domain`. `boundary` requires every module in the app to belong to
  some boundary. `BasicBoundary.Blog` claims only its own subtree. Something
  else must claim the rest of the app; here, `BasicBoundary.Reports`. Any app
  that adopts `boundary`, with or without `AshBoundary`, needs a root boundary
  like this one. Without it, the build prints a "not included in any boundary"
  warning.
- `mix.exs` adds `compilers: [:boundary] ++ Mix.compilers()`. This is the one
  manual step that `AshBoundary`'s moduledoc requires. A dependency cannot add
  itself to the `:compilers` list, so every app that uses `AshBoundary` must add
  this line. If the `:compilers` list omits `:boundary`, the build compiles and
  installs with no errors, and reports no violations.

## Running it

```
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

Run `mix deps.get` before `mix format --check-formatted`. `.formatter.exs`'s
`import_deps` needs the dependencies present on disk. Without them, the command
fails with `Unknown dependency :ash given to :import_deps` on a clean checkout.
All four commands must succeed. `mix test` runs `BasicBoundary.ReportsTest`.
This test proves that a call to the domain's exported interface from outside
its namespace works at runtime.

## Reproducing the violation yourself

`boundary` reports a cross-boundary violation as a compiler warning. The build
fails only when it also passes `--warnings-as-errors`. This example ships a
build with a green `mix test` and a green `mix compile --warnings-as-errors`.
To see the enforcement yourself:

1. Add a module outside `BasicBoundary.Blog`'s namespace that references the
   internal `Comment` resource directly. For example, add a new file
   `lib/basic_boundary/scratch_violation.ex`:

   ```elixir
   defmodule BasicBoundary.ScratchViolation do
     def run, do: BasicBoundary.Blog.Comment.__info__(:module)
   end
   ```

2. Run `mix compile`. It succeeds (exit code `0`) and prints this warning:

   ```
   warning: forbidden reference to BasicBoundary.Blog.Comment
     (module BasicBoundary.Blog.Comment is not exported by its owner boundary BasicBoundary.Blog)
     lib/basic_boundary/scratch_violation.ex:2
   ```

3. Run `mix compile --warnings-as-errors` next. `boundary` reruns and reports
   its checks on every invocation of the `:boundary` compiler. You do not need
   to force a rebuild with `rm -rf _build` first. This command exits `1`, with
   the same warning, now treated as a build failure:

   ```
   $ mix compile --warnings-as-errors
   ...
   warning: forbidden reference to BasicBoundary.Blog.Comment
     (module BasicBoundary.Blog.Comment is not exported by its owner boundary BasicBoundary.Blog)
     lib/basic_boundary/scratch_violation.ex:2
   ```

   `boundary` prints no summary line after this warning. The exit code `1` is
   what `--warnings-as-errors` depends on to fail the build.

4. Delete `lib/basic_boundary/scratch_violation.ex` to restore the example to
   its shipped state.

## Conventions for other examples

This example is the first of five sample projects. It sets the shape the other
examples follow. Examples 02 through 05 all cite this section; example 05, a real
Phoenix application, notes the two places it deliberately deviates.

- **Directory**: use `examples/NN_short_name/`, with a two-digit prefix and a
  `snake_case` name.
- **Standalone Mix project**: give each example its own `mix.exs`, `lib/`,
  `test/`, `.formatter.exs`, and `config/config.exs`. Do not share the root
  repo's `_build` or `deps`. Each example depends on
  `{:ash_boundary, path: "../.."}`, plus any other dependency it needs, for
  example `:ash`. Use `Ash.DataLayer.Ets` for resources, so no example needs an
  external database. Commit each example's `mix.lock`, the same as the root
  project's. Do not add `mix.lock` to any `.gitignore`. An example must build
  reproducibly, without re-resolving dependency versions on every checkout.
- **`compilers: [:boundary] ++ Mix.compilers()`**: add this line to every
  example's `mix.exs`, with no exception. This is the one manual step the
  library requires of a consumer, so every example must show it concretely.
- **A plain root-level `use Boundary` module is mandatory in every example.**
  See `lib/basic_boundary.ex` for this example's version. `boundary` requires
  every module in the app to belong to some boundary. A domain extended with
  `AshBoundary` claims only its own namespace. Give any other module in the
  example its own boundary, or claim it under one plain `use Boundary` module
  at the application's root. If an example skips this, the build only prints a
  "not included in any boundary" warning for the unclassified module, and the
  forbidden-reference check never fires for references from that module. This
  silently disables violation detection for it. An example may give its
  non-domain code its own boundary in place of the app-root module; that
  boundary has the same silent gap unless it also declares every dependency it
  needs. Follow the root-claiming-the-rest structure: it is the structure that
  makes the forbidden-reference check fire correctly. This is the single most
  important structural requirement in this example series. Sample project 4,
  whose entire point is a caught violation, must get this right.
- **The root repo's `.gitignore`** ignores `examples/*/_build/`,
  `examples/*/deps/`, `examples/*/doc/`, and `examples/*/cover/` in one place, so
  an example written by hand needs no `.gitignore` of its own duplicating those
  lines. Examples 01 through 04 have none. Example 05 is the exception: it was
  generated by `mix phx.new`, which writes a `.gitignore` as part of the
  generated project, and that file is kept as generated rather than deleted to
  match a convention. It is committed, and it covers a few entries the root file
  does not (`/.fetch`, `example-*.tar`). Keeping a generator's own output intact
  is worth more here than enforcing uniformity across the series.
- **Prove the point.** Prove an example's happy path with a real `mix test` in
  that example's own project. An example whose whole point is a caught
  violation is the exception: `boundary` reports violations as warnings by
  default, so catching one as a hard failure needs `--warnings-as-errors`, a
  separate invocation from `mix test`. This example's shipped build stays
  green. It demonstrates the caught violation as a documented, reproducible
  README walkthrough, shown above. Sample project 4, whose entire reason to
  exist is a caught violation, needs its own approach to automate that, for
  example a fixture excluded from `elixirc_paths` that a dedicated test
  compiles on demand and asserts fails. Pick the approach that fits what that
  example demonstrates, and document the choice there.
- **Gate**: every example must independently pass, from within its own
  directory: `mix deps.get && mix format --check-formatted && mix compile
  --warnings-as-errors && mix test`, in that order. Run `mix deps.get` first:
  `.formatter.exs`'s `import_deps` needs the dependencies present on disk, and
  fails with `Unknown dependency :ash given to :import_deps` on a clean
  checkout otherwise. Each example runs its own format check, because the root
  project's `.formatter.exs` does not reach into `examples/`. The root repo's
  `.github/workflows/ci.yml` runs this gate for every example, as an `examples`
  matrix job with one leg per example, each with its own `deps`/`_build` cache.
  The matrix lists the example directory names explicitly rather than globbing
  `examples/*/`, so **adding a sixth example means adding its directory name to
  that matrix**; until it is listed, CI will not check it at all. A project whose
  point is a caught violation still needs this gate to pass overall; the
  violation itself is demonstrated without making the shipped build red.
