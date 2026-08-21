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
- Every module named in `exports` in the `boundary` block.

A resource whose only code interface is on the resource module itself
(`code_interface do ... end` inside `use Ash.Resource`) is internal. Declaring
the interface on the domain is what makes a resource public.

Exports are module-level, not function-level. A `define` publishes every public
function on that resource module. There is no way to export one action and
withhold another on the same module.

`exports` covers public modules that are not resources, such as an
`Ash.Type.Enum` named in an exported resource's attribute types:

```elixir
boundary do
  exports [MyApp.Blog.PostStatus]
end
```

Naming a resource of the domain there is rejected at compile time. Give it a
domain-level `define` instead.

## deps

`deps` lists the other boundaries this domain may reference. It is never
inferred, and passes straight through to `boundary`. Each entry should be a
boundary: another `Ash.Domain` extended with AshBoundary, or a module that
calls `use Boundary`. AshBoundary does not check this itself; an entry that
is not a boundary is reported by `boundary`'s own compiler, the same as it
would be for a hand-written `use Boundary, deps: [...]`.

```elixir
boundary do
  deps [MyApp.Accounts, {MyApp.Codegen, :compile}]
end
```

A bare module permits every kind of reference. `{module, :compile}` narrows it to
compile-time references, so an ordinary runtime call becomes a violation.

A dep grants access to the other domain's exports only.

## Passed through unchanged

`check`, `type`, and `dirty_xrefs` in the `boundary` block go straight to
`boundary`, exactly as they would on a hand-written `use Boundary`. AshBoundary
applies no default and no interpretation of its own to any of them; see
`Boundary`'s own docs for what each one does. Left unset, a domain gets
whatever `boundary` itself defaults to, or whatever the consuming project sets
in `mix.exs` under `boundary: [default: [check: ..., type: ...]]`.

## Relationships between domains

`boundary` does not check alias references by default, and AshBoundary sets no
`check` option of its own. A relationship (`belongs_to`, `has_many`, and so on)
naming a resource in another domain compiles to an alias reference, so it is
not checked unless the domain declares `check: [aliases: true]` itself. A
relationship in either direction, or in both directions at once, compiles
cleanly with no `deps` entry and no export required on the far side.

A `define`d call into another domain, by contrast, is a `:call` reference and
is always checked. To also enforce relationships, opt in per domain:

```elixir
defmodule MyApp.Orders do
  use Ash.Domain, extensions: [AshBoundary]

  boundary do
    deps [MyApp.Customers]
    check [aliases: true]
  end
end
```

With that set, a relationship into a non-exported or undeclared domain is
reported the same way a `:call` reference would be. Replace it with an id
attribute and a calculation that reads the other domain through its exported
interface:

```elixir
# In MyApp.Orders.Order
attribute :customer_id, :uuid

calculate :customer_name, :string, MyApp.Orders.Order.Calculations.CustomerName
```

The calculation calls a `define`d interface function on `MyApp.Customers`. Ash
passes `calculate/3` the whole batch of records, so collect the ids and make one
call rather than one call per record.

## Constraints

Resources and exported modules must be namespaced under their domain.
AshBoundary raises at compile time otherwise, because `boundary` assigns modules
to boundaries by name nesting and can neither export nor protect a module outside
the namespace.

Do not also write `use Boundary` on a domain extended with AshBoundary. Both
install a declaration and source order decides the winner, so AshBoundary rejects
it. To write the declaration by hand, drop the extension.

Domains are declared `top_level?: true`, because Ash domains do not nest inside
one another. A domain is therefore a sibling of every other boundary in the
application, whatever namespace it sits under.

## Boundaries you write by hand

A module that is not a domain, such as a Phoenix web layer, declares its own
boundary with `use Boundary`. An AshBoundary domain carries no defaults
`use Boundary` would not also carry, so the two behave the same way: set
`check: [aliases: true]` explicitly on whichever one needs alias references
checked, or a reference that only names a module goes unchecked.

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

## Clarity

With [`clarity`](https://hex.pm/packages/clarity) in the consuming project, a
"Boundary Dependencies" tab appears on every AshBoundary domain and on the
application. It holds a Graphviz diagram of the domain's `deps`, followed
recursively, rooted at that domain. Clicking a node opens that domain in Clarity.
A `{module, :compile}` dep is a dashed edge, and a dep declared by hand with
`use Boundary` is drawn as a module rather than a domain.

Domains sit in tiers by their distance from the domains that depend on nothing,
and an edge a longer path already implies is left out. A compile-time edge is
kept unless the implying path is compile-time throughout.

Nothing to configure. AshBoundary registers the content provider through its own
application environment, and `AshBoundary.Clarity.DomainDependencies` is only
compiled when `clarity` is available, so a project without it is unaffected.
