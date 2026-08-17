# AshBoundary

[![CI](https://github.com/mbuhot/ash_boundary/actions/workflows/ci.yml/badge.svg)](https://github.com/mbuhot/ash_boundary/actions/workflows/ci.yml)

Boundary declarations for [Ash](https://hexdocs.pm/ash) domains, built on top of
[`boundary`](https://hex.pm/packages/boundary).

`AshBoundary` is a Spark DSL extension for `Ash.Domain` that derives a `boundary`
declaration from the DSL you already wrote, so that only a domain's intentional public
API — its own module, plus any resource with a domain-level `define` — is reachable
from outside code. Everything else under the domain's namespace is internal, and
`boundary`'s compiler enforces that line on every build.

## Why

Ash domains are easy to reach into from anywhere else in an application. Nothing stops
one domain's resource from holding a direct relationship to another domain's resource,
and that coupling is invisible right up until it's the refactor you can no longer do.
`AshBoundary` makes it visible immediately, at compile time, and the fix it points
toward is always the same one: replace the direct relationship with a **calculation**
that calls a function on the other domain's exported interface, instead of reaching
into its resource directly. See [the decoupling guide](guides/decoupling-with-calculations.md)
for the full story, or jump straight to
[`examples/03_decoupling_via_calculation`](examples/03_decoupling_via_calculation) for
the runnable before/after.

## Installation

Add `ash_boundary` and `boundary` to your `mix.exs` deps:

```elixir
def deps do
  [
    {:ash_boundary, "~> 0.1.0"},
    {:boundary, "~> 0.10", runtime: false}
  ]
end
```

## Usage

Extend a domain with `AshBoundary` and, optionally, declare which other boundaries it's
allowed to depend on:

```elixir
defmodule MyApp.Blog do
  use Ash.Domain, extensions: [AshBoundary]

  boundary do
    deps [MyApp.Accounts]
  end

  resources do
    resource MyApp.Blog.Post do
      define :get_post, action: :read
      define :update_post, action: :update
    end

    resource MyApp.Blog.Comment do
      # no domain-level define, so it stays internal
    end
  end
end
```

`MyApp.Blog.Post` is now part of `MyApp.Blog`'s public API and may be referenced from
anywhere; `MyApp.Blog.Comment` may only be referenced from inside `MyApp.Blog`'s own
namespace; and `MyApp.Blog` itself may only reach into `MyApp.Accounts`, not any other
domain.

### The one manual step: add the boundary compiler

**This is the step every example and every report of "AshBoundary isn't doing
anything" comes back to.** `AshBoundary` declares boundaries; it cannot enforce them,
because enforcement lives in `Mix.Tasks.Compile.Boundary`, and a dependency can never
add itself to your app's `:compilers` list. You have to do it yourself, once, in your
own `mix.exs`:

```elixir
def project do
  [
    app: :my_app,
    compilers: [:boundary] ++ Mix.compilers(),
    # ...
  ]
end
```

Skip this and there is no error, no warning, nothing to notice: every declaration is
still computed and installed correctly, and not one violation is ever reported. If a
reference you expected to be rejected compiles cleanly, check this first.

## Examples

Four small, standalone Mix projects under [`examples/`](examples), each demonstrating
one part of the story:

- [`01_basic_boundary`](examples/01_basic_boundary) — the smallest possible setup: one
  domain, no `boundary do ... end` section at all, showing that AshBoundary's default
  (no deps, strict enforcement) is already what most domains want.
- [`02_exported_vs_internal`](examples/02_exported_vs_internal) — two resources that
  both generate real, callable functions, exported completely differently: a
  domain-level `define` makes a resource exported, a resource's own
  `code_interface` does not.
- [`03_decoupling_via_calculation`](examples/03_decoupling_via_calculation) — the core
  pattern this library exists for: a direct cross-domain relationship (shown failing to
  compile) replaced by a calculation that calls the other domain's exported interface
  (shown working end to end).
- [`04_deliberate_violation`](examples/04_deliberate_violation) — a domain that reaches
  straight into a sibling domain's internal resource, both by a plain function call and
  by an Ash relationship, with a real `mix test` asserting that both are caught by
  `mix compile --warnings-as-errors`.

Each example's own README walks through what it shows, how to run it, and how to
reproduce its violation (or, for `04`, how the violation is proven automatically).

## Documentation

Full API docs, the DSL cheat sheet for `boundary do ... end`, and the decoupling guide
are published at [hexdocs.pm/ash_boundary](https://hexdocs.pm/ash_boundary) once this
package is released, and in the meantime at
[mbuhot.github.io/ash_boundary](https://mbuhot.github.io/ash_boundary/), built from
`main` by [`.github/workflows/docs.yml`](.github/workflows/docs.yml). Generate them
locally with:

```
mix docs
```

## Status

Pre-1.0. The DSL extension, its transformers, and the required compile-time validation
(`AshBoundary.Transformers.ValidateDomain`) are in place and covered by tests, along
with the four sample projects above. The public API may still change before a `1.0`
release.

## License

MIT — see [LICENSE](LICENSE).
