defmodule AshBoundary.Test.Blog.Post do
  @moduledoc false
  use Ash.Resource, domain: AshBoundary.Test.Blog

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshBoundary.Test.Blog.Comment do
  @moduledoc false
  use Ash.Resource, domain: AshBoundary.Test.Blog

  code_interface do
    define(:read_comments, action: :read)
  end

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshBoundary.Test.Blog do
  @moduledoc """
  Fixture domain: `Post` has a domain-level `define` and is therefore exported.

  `Comment` declares a code interface on the resource module itself and none on the
  domain, so it stays internal — the distinction design rule 1 turns on.
  """

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  resources do
    resource AshBoundary.Test.Blog.Post do
      define(:get_post, action: :read)
    end

    resource(AshBoundary.Test.Blog.Comment)
  end
end
