# AshBoundary

Boundary declarations for [Ash](https://hexdocs.pm/ash) domains, built on top of
[`boundary`](https://hex.pm/packages/boundary).

`AshBoundary` is a Spark DSL extension for `Ash.Domain` that lets a domain declare
which of its modules are part of its public API. By default, only the domain
module itself is exported — every other module under the domain's namespace
(resources, calculations, changes, etc.) is treated as internal and enforced by
`boundary`'s compiler checks.

## Why

Ash domains are easy to reach into from other parts of an application, which
encourages tight coupling between domains — for example, one domain's resource
holding a direct relationship to another domain's resource. `AshBoundary` makes
that coupling visible and preventable at compile time, and the accompanying
sample projects demonstrate the alternative: replacing a cross-domain
relationship with a calculation that calls a function on the other domain's
(exported) module.

## Status

Early development — design and implementation in progress.
