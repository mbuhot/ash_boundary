defmodule BasicBoundary.Blog do
  @moduledoc """
  This module is a single `Ash.Domain`, extended with `AshBoundary`. It shows
  the library's default enforcement, with no other domains involved.

  This domain has no `boundary do ... end` section. The section is optional. A
  domain without one still gets a boundary with `deps: []`, the strictest and
  most useful default. See the `AshBoundary` moduledoc.

  `AshBoundary` computes each domain's exports from its resources'
  domain-level `define` calls:

    * `Post` carries a domain-level `define` below. `Post` and the domain
      module itself are the only exports of `BasicBoundary.Blog`.
    * `Comment` carries no domain-level `define`, so it stays internal. Code
      outside this domain's namespace, for example `BasicBoundary.Reports`,
      may call `BasicBoundary.Blog.create_post!/1` and
      `BasicBoundary.Blog.get_post!/1`. A direct reference to
      `BasicBoundary.Blog.Comment` from outside is a boundary violation. See
      the README for how to reproduce that.
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
