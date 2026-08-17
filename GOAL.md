# AshBoundary — Project Goal

Build "AshBoundary": a Hex library that lets an Ash Domain declare a `boundary`
(hex.pm/packages/boundary) so only its intentional public API is reachable from
outside code, catching accidental cross-domain coupling at compile time.

REPO: https://github.com/mbuhot/ash_boundary (already git-initialized, README
pushed to main). Elixir library, package name `ash_boundary`, module namespace
`AshBoundary`. MIT license, maintained by mbuhot.

## Core mechanism

AshBoundary is a Spark DSL extension for `Ash.Domain`. A consuming app writes:

    defmodule MyApp.Blog do
      use Ash.Domain, extensions: [AshBoundary]

      boundary do
        deps [MyApp.Accounts]   # other domains/boundaries this one may depend on
      end

      resources do
        resource MyApp.Blog.Post do
          define :get_post, action: :read
          define :update_post, action: :update
        end

        resource MyApp.Blog.Comment do
          # no domain-level define -> stays internal
        end
      end
    end

The extension must compute the underlying `Boundary` declaration and inject the
equivalent of `use Boundary, deps: ..., exports: ...` into the domain module.
Research Spark's transformer API (`Spark.Dsl.Transformer.eval/3` or equivalent)
for injecting quoted code into the module being compiled, and read Boundary's
own source/`Boundary.Definition` to confirm the right integration point — this
is the first real technical risk in the project and should be resolved early
with a spike before building the rest of the DSL around it.

## Confirmed design rules (do not re-litigate these)

1. **Export computation is automatic, not manually declared.** The domain's
   `exports` list = {the domain module itself} ∪ {every resource module that
   has at least one domain-level `define` in the `resources` block}. Resources
   whose *only* code interface is declared on the resource module itself
   (`code_interface do define ... end` inside `use Ash.Resource`) are internal
   and excluded from exports.

2. **`deps` is user-declared, not inferred.** The whole point of Boundary is
   forcing explicit acknowledgment of cross-boundary dependencies, so the
   `boundary do deps [...] end` DSL option is how a domain admits it calls into
   another domain's exported module (typically via a calculation, see below).

3. **No transitive export propagation.** If an exported resource has a loaded
   relationship to a non-exported resource, that is a real, intended boundary
   violation — not something to silently paper over. This is deliberate: it's
   the signal that the relationship needs a code interface, or needs replacing
   with a decoupled calculation.

4. **Known accepted limitation:** Boundary's `exports` is module-level, not
   member-level — there's no way to export "just the struct" without also
   exposing any functions defined directly on that resource module. Exporting
   a resource for struct access (so external code can receive it from a read
   action and pass it into an update action) is an accepted trade-off, not a
   bug to work around with custom enforcement.

## The decoupling story (the actual point of this library)

Docs and samples must teach: when two domains have a direct resource-to-resource
relationship across the boundary line, replace it with a **calculation** on one
side that calls a function on the *other domain's exported module* (its code
interface), rather than reaching directly into the other domain's resource.
This is the pattern the whole library exists to make visible and enforceable.

## Deliverables

- `mix.exs` scaffolding: deps on `ash`, `spark`, `boundary`; `.formatter.exs`
  with Spark's locals_without_parens setup for the `boundary` DSL section.
- `AshBoundary` Spark DSL extension: DSL section + entities for `boundary do
  deps [...] end`, a transformer that computes exports and injects the
  Boundary declaration, and a verifier — required, not optional — that raises
  a clear compile-time error when `deps` references something that isn't a
  domain module extended with AshBoundary (or another recognizable boundary),
  rather than letting that surface as an opaque Boundary-library error later.
- Test suite, including tests that actually prove a boundary violation is
  caught (research how `boundary`'s own test suite verifies violations — it
  likely doesn't rely on failing a real `mix compile`, look for a programmatic
  check API — and follow the same approach rather than inventing your own).
- Multiple small, focused sample projects (per earlier decision — NOT one big
  combined app):
    1. Basic boundary setup on a single domain, showing default enforcement.
    2. A resource with domain-level `define` (exported) vs. a resource with
       only resource-level `code_interface` (internal) side by side.
    3. Two domains with a direct cross-domain resource relationship replaced
       by a calculation that calls the other domain's exported function —
       the core decoupling pattern, shown as a before/after or two variants.
    4. A deliberate boundary violation (reaching into a non-exported module)
       that demonstrates the compiler catching it.
    5. A Phoenix LiveView app where the web layer may pattern-match on
       resource structs read from the domain and call the domain's own
       declared functions, but is forbidden from calling `Ash.*` directly.
       Added mid-project at the user's request (not part of the original
       four). Built and shipped as `examples/05_phoenix_liveview`; the
       mechanism below reflects what was actually verified, not the
       original plan (two points changed after real research and review).

       **Mechanism, as verified:** no AshBoundary changes needed. The web
       layer gets a plain `use Boundary, type: :strict` (not an Ash
       domain), with `deps: [DomainModule, AshPhoenix.Form]`. `type:
       :strict` alone already forbids any external-app reference not
       backed by an explicit `deps` entry — an separate `check: [apps:
       [...]]` allowlist, the original plan, turned out to be redundant
       under `:strict` and was dropped. `:ash`/`:spark` stay out of
       `deps`, so any direct reference to them is caught. A plain `use
       Boundary` does NOT get AshBoundary's `aliases: true` default (that
       default only applies to domains AshBoundary itself manages), so the
       web layer's boundary must set `check: [aliases: true]` explicitly
       or it misses relationship-shaped/bare-alias references the same way
       unit 11 found domains missed them before the fix.

       **Structural requirement, discovered the hard way:** `boundary`
       only permits a dependency on a sibling, a parent, or a parent's dep
       — never on an arbitrary descendant of another top-level boundary.
       `mix phx.new`'s default layout (`MyAppWeb` top-level, domain nested
       one level under `MyApp`) makes the web layer and the domain NOT
       siblings, so the web layer cannot depend on the nested domain
       directly. Fix: for a single-domain app, make the top-level app
       module the domain itself (no extra nesting level) so the web layer
       and the domain are natural top-level siblings. A supervision-tree
       module that starts the endpoint needs `top_level?: true` to escape
       being classified as a child of the domain boundary it's nested
       under.

       Resource attributes in this example stick to plain types (no
       `Ash.CiString` etc.) so no `Ash.*` struct ever needs to appear in
       the web layer's pattern-matching surface — a deliberate
       simplification, not a limitation of the mechanism.

       **Loads:** no `Ash.load` carve-out. An apparent need for it in the
       web layer is a design smell fixed by a `prepare build(load: [...])`
       on the domain's read action so the returned struct already comes
       back fully loaded.

       **Errors:** a second instance of design rule 4's class of
       limitation — `boundary` has no way to allow `Ash.Error.*` while
       still blocking `Ash.read!`/`Ash.get!` within the same `:ash`
       application, since the app-level check has no module granularity.
       Fix: the domain module is inside the same boundary as Ash, so it
       translates any Ash error to a plain, domain-owned value (an atom, a
       string via `Exception.message/1`, a map) before returning, so the
       web layer only ever pattern-matches on plain data.

       **Forms, as verified (changed from the original plan):** Ash's
       code interface generation, when a domain has `extensions:
       [AshBoundary, AshPhoenix]`, auto-generates a `form_to_<name>`
       function for every `define`d create/update/destroy action,
       pre-bound to the right resource and action. The web layer calls
       THIS domain function, never `AshPhoenix.Form.for_create/2` (etc.)
       directly with the resource module — the original plan assumed the
       raw resource module would need exporting for form construction;
       verified research showed Ash already solves this one level up.
       Bonus: since `form_to_*` only exists for actions the domain chose
       to `define`, this also stops the web layer from building a form
       for an arbitrary, non-exported action. One honestly-disclosed
       residual gap remains: `AshPhoenix.Form.for_create(Resource,
       :whatever)` called directly still compiles, because the resource
       stays exported for legitimate struct pattern-matching and
       `boundary` has no function-level export granularity — a third
       instance of design rule 4's class of limitation, not a bug to
       chase further.
- Docs: README (expand the existing one), moduledocs, and a guide walking
  through the decoupling pattern. Wire up `spark.cheat_sheets` for the
  `boundary` DSL section and include the generated cheat sheet in
  `mix docs` output — this is standard for every Ash/Spark extension and is
  required here too, not conditional on the DSL's size.
- Add `credo` and `dialyxir` as `:dev, :test` deps. Both are required, not
  optional — no "if you add them" hedging.
- CI: GitHub Actions running `mix test`, `mix format --check-formatted`,
  `mix credo --strict`, and `mix dialyzer`. All four must pass before a commit
  is pushed; treat a red check the same as a failing test, not a follow-up.

## Working conventions

- Track your own checklist with TaskCreate/TaskUpdate across the run.
- Commit in small, logically-scoped increments with tests green; push directly
  to `main` on the repo above (matches how this repo was already set up) —
  no need to open PRs against yourself for a solo new library.
- Where this brief is silent and a judgment call is needed, make the most
  Ash/Spark-idiomatic choice and keep moving; note any notable deviations in
  commit messages rather than stalling for input.
