# AshBoundary

[![CI](https://github.com/mbuhot/ash_boundary/actions/workflows/ci.yml/badge.svg)](https://github.com/mbuhot/ash_boundary/actions/workflows/ci.yml)

AshBoundary is a Spark DSL extension for [Ash](https://hexdocs.pm/ash) domains.
It derives a [`boundary`](https://hex.pm/packages/boundary) declaration from the domain DSL.
The `boundary` compiler enforces the declaration on each build.

- The domain module is public.
- Each resource with a domain-level `define` is public.
- All other modules in the domain's namespace are internal.

## Why

All application code can reference a domain's internal resources.
A resource in one domain can hold a direct relationship to a resource in a different domain.
This coupling makes future refactors difficult.

AshBoundary reports this coupling at compile time.
To remove the coupling, replace the direct relationship with a calculation.
The calculation calls a function on the public interface of the other domain.

See [the decoupling guide](guides/decoupling-with-calculations.md) and
[`examples/03_decoupling_via_calculation`](examples/03_decoupling_via_calculation).

## Installation

Add `ash_boundary` and `boundary` to the deps in `mix.exs`:

```elixir
def deps do
  [
    {:ash_boundary, "~> 0.1.0"},
    {:boundary, "~> 0.10", runtime: false}
  ]
end
```

## Usage

Add `AshBoundary` to the extensions of a domain.
To permit dependencies on other boundaries, declare them in a `boundary` block:

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

    resource MyApp.Blog.Comment
  end
end
```

This configuration has these effects:

- `MyApp.Blog.Post` is public. All modules can reference it.
- `MyApp.Blog.Comment` is internal. Only modules in the `MyApp.Blog` namespace can reference it.
- `MyApp.Blog` can depend on the `MyApp.Accounts` boundary only.

## Add the boundary compiler (required)

AshBoundary declares the boundaries.
The `Mix.Tasks.Compile.Boundary` compiler enforces them.
A dependency cannot add itself to the `:compilers` list of your application.

Add the compiler to the project configuration in `mix.exs`:

```elixir
def project do
  [
    app: :my_app,
    compilers: [:boundary] ++ Mix.compilers(),
    # ...
  ]
end
```

If the `:compilers` list does not include `:boundary`, the build reports no violations.
If an expected violation compiles without an error, do this check first.

## Examples

Four standalone Mix projects are in [`examples/`](examples):

- [`01_basic_boundary`](examples/01_basic_boundary): one domain with the default configuration. The default configuration has zero deps and strict enforcement.
- [`02_exported_vs_internal`](examples/02_exported_vs_internal): a domain-level `define` exports a resource. A resource-level `code_interface` keeps the resource internal.
- [`03_decoupling_via_calculation`](examples/03_decoupling_via_calculation): a calculation replaces a cross-domain relationship.
- [`04_deliberate_violation`](examples/04_deliberate_violation): a test shows that `mix compile --warnings-as-errors` catches two boundary violations.

Each example has a README with run instructions.

## Documentation

The documentation is published at
[mbuhot.github.io/ash_boundary](https://mbuhot.github.io/ash_boundary/).
After the package release, it is published at
[hexdocs.pm/ash_boundary](https://hexdocs.pm/ash_boundary).

To generate the documentation locally, run:

```
mix docs
```

## Status

Pre-1.0. The public API can change before the 1.0 release.

## License

MIT. See [LICENSE](LICENSE).
