defmodule BasicBoundary.Blog do
  @moduledoc """
  A single Ash domain, extended with `AshBoundary`, showing the library's default
  enforcement with no other domains involved.

  No `boundary do ... end` section is written here at all — the section is optional,
  and a domain that omits it still gets a boundary with `deps: []`, which is the
  strictest and most useful default (see the `AshBoundary` moduledoc). That default is
  exactly what this example wants to show: with zero configuration beyond the
  `extensions: [AshBoundary]` line, every module under `BasicBoundary.Blog.*` becomes
  enforced.

  Exports are computed, not listed by hand:

    * `Post` carries a domain-level `define` below, so it and the domain module itself
      are the only two things `BasicBoundary.Blog` exports.
    * `Comment` carries no domain-level `define`, so it stays internal. Code outside
      this domain's namespace (see `BasicBoundary.Reports`) may call
      `BasicBoundary.Blog.create_post!/1` and `BasicBoundary.Blog.get_post!/1`, but a
      direct reference to `BasicBoundary.Blog.Comment` from outside would be a boundary
      violation — see the README for how to reproduce that.
  """

  use Ash.Domain, extensions: [AshBoundary]

  resources do
    resource BasicBoundary.Blog.Post do
      define :create_post, action: :create
      define :get_post, action: :read, get_by: [:id]
    end

    resource BasicBoundary.Blog.Comment
  end
end
