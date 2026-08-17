# Rules for working with AshBoundary

AshBoundary derives a [`boundary`](https://hex.pm/packages/boundary) declaration
from an `Ash.Domain`'s DSL, so the compiler reports references that cross a
domain's public API.

## Setup

Add the `:boundary` compiler to the consuming project. Without it every
declaration is still computed and no violation is ever reported:

```elixir
def project do
  [
    app: :my_app,
    compilers: [:boundary] ++ Mix.compilers(),
    # ...
  ]
end
```

Extend a domain:

```elixir
defmodule MyApp.Blog do
  use Ash.Domain, extensions: [AshBoundary]

  boundary do
    deps [MyApp.Accounts]
  end

  resources do
    resource MyApp.Blog.Post do
      define :get_post, action: :read
    end

    resource MyApp.Blog.Comment
  end
end
```

## What is public

- The domain module.
- Every resource with at least one domain-level `define` in the `resources` block.

A resource whose only code interface is on the resource module itself
(`code_interface do ... end` inside `use Ash.Resource`) is internal. Declaring
the interface on the domain is what makes a resource public.

Exports are module-level, not function-level. A `define` publishes every public
function on that resource module. There is no way to export one action and
withhold another on the same module.

## deps

`deps` lists the other boundaries this domain may reference. It is never
inferred. Each entry must be a boundary: another `Ash.Domain` extended with
AshBoundary, or a module that calls `use Boundary`.

```elixir
boundary do
  deps [MyApp.Accounts, {MyApp.Codegen, :compile}]
end
```

A bare module permits every kind of reference. `{module, :compile}` narrows it to
compile-time references, so an ordinary runtime call becomes a violation.

A dep grants access to the other domain's exports only.

## Replace a cross-domain relationship with a calculation

A relationship names another domain's resource module, and AshBoundary sets
`check: [aliases: true]`, so `boundary` reports it. Do not add the target
resource to `exports` to silence it. Store the id and read the other domain
through its exported interface:

```elixir
# In MyApp.Orders.Order
attribute :customer_id, :uuid

calculate :customer_name, :string, MyApp.Orders.Order.Calculations.CustomerName
```

The calculation calls a `define`d interface function on `MyApp.Customers`. Ash
passes `calculate/3` the whole batch of records, so collect the ids and make one
call rather than one call per record.

## Constraints

Resources must be namespaced under their domain. AshBoundary raises at compile
time otherwise, because `boundary` assigns modules to boundaries by name nesting
and can neither export nor protect a module outside the namespace.

Do not also write `use Boundary` on a domain extended with AshBoundary. Both
install a declaration and source order decides the winner, so AshBoundary rejects
it. To write the declaration by hand, drop the extension.

Domains are declared `top_level?: true`, because Ash domains do not nest inside
one another. A domain is therefore a sibling of every other boundary in the
application, whatever namespace it sits under.

## Boundaries you write by hand

A module that is not a domain, such as a Phoenix web layer, declares its own
boundary with `use Boundary`. Such a boundary does not inherit AshBoundary's
defaults, so set `check: [aliases: true]` on it explicitly or a reference that
only names a module goes unchecked.

To forbid a whole application, name it in `check: [apps: [...]]` and leave it out
of `deps`:

```elixir
defmodule MyAppWeb do
  use Boundary,
    check: [aliases: true, apps: [:ash]],
    deps: [MyApp.Blog, Ash.Error.Invalid]
end
```

`deps` entries are module-granular for external applications, so
`Ash.Error.Invalid` above permits that struct while `Ash.read!/1` and the rest of
`:ash` stay rejected. An entry exports only the module named; a nested error
module needs its own entry.

## Introspection

`AshBoundary.Info.deps/1` and `AshBoundary.Info.exports/1` accept a compiled
domain module or the DSL state a transformer receives.
