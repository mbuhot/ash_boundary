# AshBoundary

[![CI](https://github.com/mbuhot/ash_boundary/actions/workflows/ci.yml/badge.svg)](https://github.com/mbuhot/ash_boundary/actions/workflows/ci.yml)

AshBoundary is a Spark DSL extension for [Ash](https://hexdocs.pm/ash) domains.
It derives a [`boundary`](https://hex.pm/packages/boundary) declaration from the domain DSL.
The `boundary` compiler enforces the declaration on each build.

## Conventions

- The domain module is public.
- Each resource that exposes a code interface in the domain is public.
- All other modules in the domain's namespace are internal.
- Referencing another domain requires an explicit `boundary` dep.


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

Add the `:boundary` compiler to the project configuration:

```elixir
def project do
  [
    app: :my_app,
    compilers: [:boundary] ++ Mix.compilers(),
    # ...
  ]
end
```

## Usage

Add `AshBoundary` to the extensions of a domain. Declare dependencies from other domains in a `boundary` block:

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


## Examples

See the [`examples/`](examples) directory. [`05_phoenix_liveview`](examples/05_phoenix_liveview) is the most realistic example.


## Documentation

Docs for latest `main` is published at
[mbuhot.github.io/ash_boundary](https://mbuhot.github.io/ash_boundary/).
Docs for versioned releases will be available at
[hexdocs.pm/ash_boundary](https://hexdocs.pm/ash_boundary).

See also the [`boundary` docs](https://hexdocs.pm/boundary).

## License

MIT. See [LICENSE](LICENSE).
