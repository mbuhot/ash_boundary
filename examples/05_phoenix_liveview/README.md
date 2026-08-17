# 05: A Phoenix LiveView web layer that cannot call `Ash.*`

This example is a Phoenix and LiveView application. The web layer can
pattern-match resource structs read from the domain. It can call the functions
the domain declares. It cannot call `Ash.read!/1`, `Ash.get!/2`, `Ash.load!/2`,
or `Ash.Query.filter/2`. It cannot match an `%Ash.Error.Invalid{}` struct. The
compiler enforces all of this.

This is sample project 5. The user asked for it during the project. It is not
one of the original four. It needs no change to AshBoundary. It combines two
independent mechanisms. One of them is not an AshBoundary feature.

```
$ mix test
18 tests, 0 failures
```

Those 18 tests include three proofs:

- `ExampleWeb.PostLiveTest` shows the LiveView renders real records, submits a
  real form, and shows real validation errors.
- `ExampleWeb.AshViolationTest` shows that two isolated builds,
  `MIX_ENV=violation` and `MIX_ENV=undefined_form`, each exit 1 with the exact
  output in this README.
- `ExampleTest` shows that the domain generates a form builder for each declared
  action, and for no undeclared action.

All three proofs are automatic. The reader does not have to reproduce any of
them.

## The two mechanisms

**1. Structs and domain functions reach the web layer.** This is the ordinary
AshBoundary mechanism, unchanged from examples 1 to 4. `Example` declares
`define`s for `Example.Post` in its `resources` block. AshBoundary
computes `exports: [Example, Example.Post]`. `ExampleWeb` declares
`deps: [Example, ...]`. The LiveView can then match `%Example.Post{}`,
read `post.title`, and call `Example.list_published_posts!/0`. Example 2
covers this part in full.

**2. `Ash.*` is locked out.** This is a separate lever in plain `boundary`.
`ExampleWeb` is not an `Ash.Domain`. It is an ordinary module with a plain
`use Boundary`. The lever is `boundary`'s treatment of other OTP applications.
The exact behaviour matters, because the obvious guess about the configuration
is wrong. See the next section.

The two levers are orthogonal. The first controls which modules of your own app
are reachable across a boundary line. The second controls which other
applications are reachable at all.

## How `boundary` decides that an external reference is forbidden

`Boundary.Checker.check_external_dep?/3` makes this decision, in
`deps/boundary/lib/boundary/checker.ex`:

```elixir
defp check_external_dep?(view, reference, from_boundary) do
  Boundary.app(view, reference.to) != :boundary and
    (from_boundary.type == :strict or
       MapSet.member?(
         with_ancestors(view, from_boundary, & &1.check.apps),
         {Boundary.app(view, reference.to), reference.mode}
       ))
end
```

Three facts follow. This example depends on all of them.

1. **The default is to check no other application.** The `boundary` default is
   `type: :relaxed`, and under it cross-application references are unrestricted.
   That default is why Ash resources call `:ash` and `:spark` without friction
   today. It is also why an unconfigured LiveView can.

2. **`check: [apps: [...]]` is not an allowlist.** It names the applications to
   start checking. Each application in the list then needs explicit `deps`
   entries. `deps` is the allowlist. `Boundary`'s own moduledoc states this:
   "The check apps list contains additional applications which are always
   checked. Any calls to given applications must be explicitly allowed via the
   `:deps` option." An application left out of the list is not checked at all.

3. **You cannot restrict `:boundary` itself.** The first clause excludes it. An
   `apps:` entry for `:boundary` does nothing. `Boundary`'s moduledoc says the
   same about `:elixir` and pure Erlang applications.
   `Mix.Tasks.Compile.Boundary` also excludes `:elixir`, `:stdlib`, `:kernel`,
   and preloaded modules from tracing.

A second rule shapes this example's module names.
`Boundary.Checker.validate_dep_allowed/4` permits a boundary to list only a
sibling, a parent, or a dep of its parent. See "Why the domain is the top-level
module".

## The shipped configuration

From `lib/example_web.ex`:

```elixir
use Boundary,
  check: [aliases: true, apps: [:ash, :spark]],
  deps: [Example, AshPhoenix.Form],
  exports: [Endpoint, Telemetry]
```

`:ash` and `:spark` are checked, and neither appears in `deps`. That is the
enforcement: any `Ash.*` reference from this namespace is a violation. Phoenix,
Plug, ExUnit and Mix are not in `check.apps`, so they are not checked and need no
entries at all. `deps` names the two things the web layer may reach: the
`Example` domain, and `AshPhoenix.Form`.

`type` keeps its default, `:relaxed`. A `type: :strict` boundary checks every
other application instead, so `deps` then has to name every Phoenix, Plug and
Telemetry module the generated web tier references. That includes the ones
`use Phoenix.Endpoint` and `use Phoenix.Router` reference on your behalf, such as
`Plug.Builder` and `Phoenix.Transports.WebSocket`. That is roughly thirty entries
to maintain, and a Phoenix upgrade can change which are needed. Naming two
applications locks `:ash` out with nothing to maintain.

**`check: [aliases: true]` is not decoration.** The `boundary` default is
`aliases: false`. Under that default, `boundary` does not check a reference that
only names a module and calls nothing. `ExampleWeb.AshAliasReference` in
`violation/` returns the `Ash.Query` module as a value, and a caller can reach
Ash through that value with `apply/3`. With `aliases: true`, `boundary` reports
it. AshBoundary turns alias checking on for every domain it manages, and this
boundary matches that posture. A plain `use Boundary` inherits nothing from
AshBoundary, so `ExampleWeb` opts in itself.

## Two tiers: `:ash` is forbidden, `:ash_phoenix` is allowed

`deps` lists `AshPhoenix.Form`. It does not list `Ash`, and `check.apps` names
`:ash` but not `:ash_phoenix`. This works because `:ash_phoenix` is a separate
OTP application from `:ash`, and the external check works per application.

This is a deliberate compromise. It is not "zero Ash surface, full stop".
Building a form, casting user input, and revalidating on each keystroke are
changeset-level operations. They need the resource's action and its changeset,
not the result of an action, so no code interface can express them.
`AshPhoenix.Form` exists for this work. It also keeps the leaky parts away from
the web layer:

- `AshPhoenix.Form.submit/2` returns `{:ok, record} | {:error, form}`. The error
  branch holds a form, never an `Ash.Error` struct. See
  `deps/ash_phoenix/lib/ash_phoenix/form/form.ex`.
- Per-field errors arrive as `{message, opts}` tuples, a binary plus a keyword
  list. They come through `AshPhoenix.Form`'s `Phoenix.HTML.FormData`
  implementation. `ExampleWeb.CoreComponents.translate_error/1`, as `mix
  phx.new` generates it, already expects that shape.
  `AshPhoenix.Form.errors/2` returns the same data directly. Its default is
  `format: :simple`, which gives `[field: "message"]`.

The form path therefore adds no `Ash.*` reference to the web layer.
`Ash.read!/1` and its relatives stay forbidden.
`violation/example_web/live/ash_read_live.ex` compiles in the same build as the
working form, and it still fails. Allowing `:ash_phoenix` does not open the door
to `:ash`.

### The domain builds the form, through a generated interface function

The web layer does not call `AshPhoenix.Form.for_create/3`. It calls
`Example.form_to_create_post/1`, an ordinary exported function on the domain.

`extensions: [AshBoundary, AshPhoenix]` on the domain is what generates it.
`AshPhoenix` is an extension, not automatic behaviour. Its moduledoc states
"An extension to add form builders to the code interface. There is currently no
DSL for this extension."
`AshPhoenix.Transformers.AddFormCodeInterfaces` builds one function for each
code interface `define`, and the name is always `:"form_to_#{interface.name}"`.

The generated function calls `AshPhoenix.Form.for_action/3` with the resource
and action already applied. The arity depends on the action type:

- A create or read interface takes options only, so `define :create_post`
  produces `form_to_create_post/0` and `form_to_create_post/1`.
- An update or destroy interface takes the record first, when
  `require_reference?` holds its default. `define :delete_post` therefore
  produces `form_to_delete_post/1` and `form_to_delete_post/2`.

The compiler prints that list, which is how this example verified it. See the
captured output for `MIX_ENV=undefined_form` below.

This is a boundary property, not only a convenience:

1. **The web layer never names the resource to build a form.** `Example.Post`
   appears in `post_live.ex` exactly once, in the `%Example.Post{} = post`
   pattern match that mechanism 1 is about.

2. **The web layer can build a form only for a declared action.** `Example.Post`
   has a real `:moderate` update action, and the domain declares no `define` for
   it. No `form_to_moderate_post` function exists in any arity, which
   `ExampleTest` asserts, and a module that calls one fails to compile, which
   `violation_form/example_web/live/undefined_form_live.ex` proves. The domain's
   `define` list is the whole form-building surface.

**One residual gap, stated plainly.** `boundary` does not close this by itself.
`Example.Post` must stay exported, because mechanism 1 requires the web layer to
match the struct. Both `AshPhoenix.Form` and `Example.Post` are therefore allowed
names in `ExampleWeb`, so a module that writes
`AshPhoenix.Form.for_create(Example.Post, :moderate)` still compiles. Verified by
compiling it. What the `form_to_*` route changes is that the correct path is now
the shortest path, and that no generated function exists for an undeclared
action. Closing the gap in the compiler would need function-level exports, which
`boundary` does not have. That is the same module-level granularity limit
AshBoundary accepts by design: `exports` name modules, not functions.

## Why `Ash.load/2` gets no exception

`violation/example_web/live/ash_load_live.ex` holds the most sympathetic
violation in this example. The LiveView already has a struct from the domain. It
wants one more calculation on that struct. `Ash.load!/2` changes no data, and
many real applications permit it.

This example forbids it. A need for `Ash.load/2` in a template is a signal. It
means the read action returned an incomplete struct. `:excerpt` and
`:word_count` are calculations, and Ash loads no calculation unless something
asks for it. The fix belongs in the domain, on one line of
`Example.Post`:

```elixir
read :list_published do
  filter expr(published? == true)
  prepare build(load: [:excerpt, :word_count], sort: [title: :asc])
end
```

`Example.list_published_posts!/0` now returns complete structs. The
LiveView reads `post.excerpt` like any other field. There is no exception to
make. This matches example 3, where the `CustomerDisplayName` calculation
declares `load/3`. State what the data needs where the data lives.

A narrow exception is also impossible. See the next section.

## Two accepted limitations of the same kind

AshBoundary accepts one granularity limitation by design. `boundary`'s
`exports` work at module level. Exporting a resource for struct access also
exposes every function on that module. This example meets a second instance of
the same class of trade-off.

**The external check works at application level.** You cannot allow
`Ash.Error.Invalid` and forbid `Ash.Query`. Both modules live in `:ash`. Letting
the web layer match one Ash error also lets it run raw queries.

The fix belongs in the domain. This makes the return shape a boundary concern,
not a matter of taste. `Example.get_post_by_id/1` is the generated code
interface. It returns `{:error, %Ash.Error.Invalid{}}` for a missing post. A
LiveView cannot handle that value without a forbidden reference, and
`violation/example_web/live/ash_error_match_live.ex` proves it. The domain
translates instead:

```elixir
def fetch_post(id) do
  case get_post_by_id(id) do
    {:ok, nil} -> {:error, :not_found}
    {:ok, post} -> {:ok, post}
    {:error, error} -> {:error, translate_error(error)}
  end
end
```

The results are `{:ok, post}`, `{:error, :not_found}`, and `{:error, message}`
with a binary message. No restriction applies to the domain module. It can call
`Ash.Error.to_error_class/1` and `Exception.message/1` freely, and that code
belongs there. `test/example_test.exs` asserts both shapes. It also asserts
the contrast case, that `get_post_by_id/1` really returns an
`%Ash.Error.Invalid{}`.

The general rule: **a domain function that can fail must return plain data.**
Use atoms, strings, and maps. Do not return an `Ash.*` struct. Bang functions
are acceptable. A raised exception is a runtime value, not a compile-time
reference. Handling an Ash error is what forces you to name one.

## Plain attribute types, deliberately

`Example.Post` uses `:string`, `:boolean`, `:integer`, and a
`uuid_primary_key`. It uses no `Ash.CiString` and no other struct in the `Ash.*`
namespace.

This is a deliberate simplification, and this README states it rather than
hiding it. A `:ci_string` attribute hands the web layer an `%Ash.CiString{}` to
render. A template that matches that struct, or calls `Ash.CiString.value/1`,
makes a real forbidden reference. The application-level granularity above gives
no narrow way to permit it. An application that wants case-insensitive strings
must translate at the domain edge, as `fetch_post/1` translates errors, or
accept an `:ash` reference in the web layer. The mechanism is sound. The type
choice is what keeps this example's claim absolute.

## Why the domain is the top-level module

Every example in this series needs a boundary that claims the app's namespace, so
that no module escapes classification. `BasicBoundary` and `DeliberateViolation`
do that job in examples 1 and 4. In this example the domain itself does it:
`Example` is both the `Ash.Domain` and the boundary over `Example.*`.

The reason is `Boundary.Checker.validate_dep_allowed/4`:

```elixir
# a boundary can depend on its parent, sibling, or a dep of its parent
if parent_boundary == to_boundary or
     parent_boundary == Boundary.parent(view, to_boundary) or
     (not is_nil(parent_boundary) and {to_boundary.name, type} in parent_boundary.deps),
```

`mix phx.new` generates `Example` and `ExampleWeb` as top-level siblings. Nesting
the domain one level deeper, as `Example.Blog`, makes it a child of `Example`. The
top-level `ExampleWeb` can then no longer name it:

```
warning: Example.Blog can't be listed as a dependency because it's not a sibling,
a parent, or a dep of some ancestor
```

AshBoundary's DSL exposes only `deps`. It has no `top_level?` option to promote a
domain out of its parent. So the layout has to give the domain and the web
boundary the sibling relationship that `deps: [Example]` needs. Three layouts do
that:

- Make the domain the top-level module. `Example` is the domain and `Example.Post`
  is the resource. This example takes this option. A single-domain Ash and Phoenix
  application does this routinely.
- Rename the web namespace to `Example.Web`, so it becomes a sibling of
  `Example.Blog` under a root `Example` boundary.
- Keep a root boundary and re-export the child domain from it. Write
  `exports: [{Blog, []}]` on `Example` and `deps: [Example]` on `ExampleWeb`. This
  works through `Boundary.Checker.exported_by_child_subboundary?/3`.

The second and third options were verified by compiling them, not by reading the
source alone. The re-export option compiles clean, and it preserves the child's
export decisions: a reference from `ExampleWeb` to
`Example.Blog.Post.Calculations.Excerpt`, which the domain does not export, still
fails. An application with several domains wants one of those two layouts. This
example has one domain, so the simplest layout is the honest one.

`Example.Application` is the only module in the `Example.*` namespace that the
domain boundary does not claim. It carries `top_level?: true`, which promotes it
into a sibling of `Example` and `ExampleWeb`. A supervision tree that starts the
endpoint is not part of the domain, and the domain must not gain a dep on
`ExampleWeb` to accommodate it.

**Nothing escapes classification.** `boundary` classifies a module by name
nesting, so this layout handles new modules in two different ways. Both were
verified by compiling them.

A new module inside an existing boundary's namespace joins that boundary and
needs no declaration. A `lib/example/stray.ex` holding `Example.Stray` compiles
clean and exits 0, and so would a future `Example.Mailer`: the `Example` domain
boundary claims it. That is the point of putting a boundary over the whole
namespace, and it is what the earlier examples' root boundary provides.

A new module outside every boundary's namespace is reported. A top-level
`TotallyStray` module, nested under neither `Example.*` nor `ExampleWeb.*`, gives:

```
warning: TotallyStray is not included in any boundary
  lib/totally_stray.ex:0
```

That warning fails `--warnings-as-errors`, so a new top-level namespace cannot
enter the app unchecked. It fails the build until it gets a boundary of its own or
a home inside one. This matters because `boundary` does not check references *from*
an unclassified module, so a silent gap there would disable enforcement for
whatever landed in it.

## The modules

| Module | Boundary | Notes |
| --- | --- | --- |
| `Example` | own (AshBoundary) | domain. Exports itself and `Post`. Adds hand-written `fetch_post/1` and `published_post_titles/0`, which return plain data |
| `Example.Post` | `Example` | exported through domain-level `define`s. Plain attribute types only. `:list_published` and `:by_id` both use `prepare build(load: [...])` |
| `Example.Post.Calculations.Excerpt` | `Example` | module calculation. Inside the domain, so it can use `Ash.*` |
| `Example.Application` | own | supervision tree. `deps: [Example, ExampleWeb]`. Seeds two posts in `:dev` only |
| `ExampleWeb` | own | the boundary this example is about. Checks `:ash` and `:spark`. `exports: [Endpoint, Telemetry]` |
| `ExampleWeb.PostLive` | `ExampleWeb` | the LiveView. Lists, selects, and creates posts with no `Ash.*` reference |
| `ExampleWeb.ConnCase` | `ExampleWeb` | test support, compiled in `:test` only |
| `ExampleWeb.{Endpoint, Router, Telemetry, Layouts, CoreComponents, ErrorHTML, ErrorJSON}` | `ExampleWeb` | as `mix phx.new` generates them |
| `ExampleWeb.AshReadLive` | `ExampleWeb` | not compiled by any normal build. Calls `Ash.read!/1` and `Ash.Query.filter/2` |
| `ExampleWeb.AshLoadLive` | `ExampleWeb` | not compiled. Calls `Ash.load!/2` on a loaded struct |
| `ExampleWeb.AshErrorMatchLive` | `ExampleWeb` | not compiled. Matches `%Ash.Error.Invalid{}` |
| `ExampleWeb.AshAliasReference` | `ExampleWeb` | not compiled. Names `Ash.Query` as a value and calls nothing. Caught only because of `check: [aliases: true]` |
| `ExampleWeb.UndefinedFormLive` | `ExampleWeb` | not compiled. Asks the domain for `form_to_moderate_post/1`, which does not exist. Lives in `violation_form/`, under its own env |

## The violation, caught

`mix.exs` keeps `violation/` out of every normal build, the same way examples 3
and 4 do. It adds the directory to `elixirc_paths` under `MIX_ENV=violation`
only:

```elixir
defp elixirc_paths(:violation), do: ["lib", "violation"]
defp elixirc_paths(:undefined_form), do: ["lib", "violation_form"]
defp elixirc_paths(:test), do: ["lib", "test/support"]
defp elixirc_paths(_), do: ["lib"]
```

There are two failing envs, not one, and the split is not cosmetic. The
`violation/` modules fail because `boundary` rejects a reference. The
`violation_form/` module fails because a function does not exist, which is an
ordinary Elixir undefined-function warning. Under `--warnings-as-errors` that
warning fails the app compile, and `boundary` runs its checks only after a
successful app compile. One env therefore cannot show both failure modes in one
invocation.

The shipped build stays green, and the modules that must not compile still ship
as real, complete code. The text below is the verbatim output of the build that
`test/example_web/ash_violation_test.exs` runs as a subprocess:

```
$ MIX_ENV=violation mix compile --warnings-as-errors
...
warning: forbidden reference to Ash.Error.Invalid
  (references from ExampleWeb to Ash.Error.Invalid are not allowed)
  violation/example_web/live/ash_error_match_live.ex:18

warning: forbidden reference to Ash
  (references from ExampleWeb to Ash are not allowed)
  violation/example_web/live/ash_load_live.ex:11

warning: forbidden reference to Ash
  (references from ExampleWeb to Ash are not allowed)
  violation/example_web/live/ash_read_live.ex:11

warning: forbidden reference to Ash.Expr
  (references from ExampleWeb to Ash.Expr are not allowed)
  violation/example_web/live/ash_read_live.ex:16

warning: forbidden reference to Ash.Query
  (references from ExampleWeb to Ash.Query are not allowed)
  violation/example_web/live/ash_read_live.ex:16

warning: forbidden reference to Ash.Query.Call
  (references from ExampleWeb to Ash.Query.Call are not allowed)
  violation/example_web/live/ash_read_live.ex:16

warning: forbidden reference to Ash
  (references from ExampleWeb to Ash are not allowed)
  violation/example_web/live/ash_read_live.ex:17

warning: forbidden reference to Ash.Query
  (references from ExampleWeb to Ash.Query are not allowed)
  violation/example_web/live/ash_alias_reference.ex:5
```

The exit code is 1.

Read the reason text closely. `(references from ExampleWeb to Ash are not
allowed)` is `boundary`'s `:invalid_external_dep_call` diagnostic. Example 4
documents a different message, `(module ... is not exported by its owner
boundary ...)`. The two messages look similar and mean different things.
Example 4's message is about a module of your own app that its owner boundary
keeps private. This message is about a whole application that the boundary does
not depend on.

One `Ash.Query.filter/2` call produces three warnings: `Ash.Query`, `Ash.Expr`,
and `Ash.Query.Call`. A macro expands into references to several modules.

Without `--warnings-as-errors`, the same command reports the same warnings and
exits 0. `boundary` reports a violation as a compiler warning. Every example in
this series has to account for that. It is why the gate below and the test both
use the flag.

### The undeclared action, refused

The second failing env proves that the domain's `define` list is the whole
form-building surface. This is the verbatim output:

```
$ MIX_ENV=undefined_form mix compile --warnings-as-errors
...
    warning: Example.form_to_moderate_post/1 is undefined or private. Did you mean:

          * form_to_create_post/0
          * form_to_create_post/1
          * form_to_delete_post/1
          * form_to_delete_post/2
          * form_to_list_posts/0

    │
  9 │     {:ok, assign(socket, form: to_form(Example.form_to_moderate_post(as: "post")))}
    │                                                ~
    │
    └─ violation_form/example_web/live/undefined_form_live.ex:9:48: ExampleWeb.UndefinedFormLive.mount/3

Compilation failed due to warnings while using the --warnings-as-errors option
```

The exit code is 1. The compiler's own suggestion list is the positive half of
the proof. `form_to_create_post` exists because the domain declares
`define :create_post`. `form_to_delete_post` takes the record first, because a
destroy interface does. No `form_to_moderate_post` appears in any arity, because
the domain declares no `define` for the `:moderate` action.

### The proof is not vacuous: the mutation test

The claim "this output proves the enforcement works" is only worth as much as its
converse. Each of the six violating lines was replaced with a legal equivalent,
and the fixture modules were left otherwise intact:

- `Ash.read!(Example.Post)` became `Example.list_posts!()`.
- The `Ash.Query` pipeline became `Example.list_published_posts!()`.
- The `Ash.load!` pipe was removed.
- `%Ash.Error.Invalid{}` became `_reason`.
- `Ash.Query` as a value became `nil`.
- `form_to_moderate_post` became `form_to_create_post`.

The results:

- `MIX_ENV=violation mix compile --force --warnings-as-errors` exits **0**, with
  **zero** `forbidden reference` warnings.
- `MIX_ENV=undefined_form mix compile --force --warnings-as-errors` exits **0**,
  with **zero** undefined-function warnings.
- `mix test test/example_web/ash_violation_test.exs` **fails**, on all three
  tests.

Every warning above therefore comes from the specific line named, and the tests
depend on those lines. The violating lines were then restored, and the suite is
green again.

## Running it

```
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

Run `mix deps.get` first. `.formatter.exs`'s `import_deps` needs the deps
present on disk, and fails with `Unknown dependency :ash given to :import_deps`
on a clean checkout otherwise. This is the gate every example in this series
uses. All four commands succeed. The `mix precommit` alias from `mix phx.new`
remains in place and does the same work in a different order.

`mix test` shells out to the two failing envs, so the first run on a clean
checkout compiles this project's dependencies for `_build/violation` and
`_build/undefined_form` as well. That takes a few minutes once. Later runs reuse
both build directories.

To see the application run:

```
mix phx.server   # then open http://localhost:4000
```

`config/dev.exs` sets `seed_posts?: true`. `Example.Application` then inserts
two posts through `Example.create_post!/1` on boot.
`Ash.DataLayer.Ets` keeps records in the memory of the running node, so a fresh
server shows an empty list without the seed. The page lists the posts with their
excerpts and word counts. The "Show" buttons, the create form, and live reload
all work.

This example needs two things from the environment. Neither is specific to this
example:

- `mix test` needs a C toolchain and `cmake`. `:lazy_html` compiles a native
  library, and `Phoenix.LiveViewTest` uses it to parse rendered HTML in
  Phoenix 1.8 and LiveView 1.2. On Debian or Ubuntu, run
  `apt-get install build-essential cmake`.
- Live reload needs `inotify-tools` on Linux. Run
  `apt-get install inotify-tools`. Any Phoenix application needs this.

### Two deviations from examples 1 to 4

Both are deliberate.

- **The ETS data layer is not private.** Examples 1 to 4 use `private? true`,
  which scopes the table to the process that created it. That suits a test-only
  example. It is wrong here. A web request runs in a different process from the
  one that wrote the data, and each LiveView mount is another process again. A
  private table renders an empty list on every page. The tests clear the shared
  table between runs instead, through `Example`'s exported `list_posts` and
  `delete_post`.
- **The domain is the top-level module, and there is no separate root boundary
  module.** `Example` is both. See "Why the domain is the top-level module". Every
  module still lands in a boundary, which is the property the earlier examples'
  root boundary exists to provide.

See the "Conventions for other examples" section in
`examples/01_basic_boundary/README.md` for the conventions this example follows
without change. They are the standalone Mix project, the committed `mix.lock`,
`Ash.DataLayer.Ets`, the `compilers: [:boundary] ++ Mix.compilers()` entry that
the consuming app declares itself, and the absence of any project-level
`boundary: [default: [check: ...]]` configuration.
