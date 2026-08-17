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

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshBoundary.Test.Blog do
  @moduledoc """
  Fixture domain: `Post` has a domain-level `define` and is therefore exported,
  `Comment` has none and stays internal.
  """

  use Ash.Domain, extensions: [AshBoundary.Test.Extension], validate_config_inclusion?: false

  boundary do
    deps([])
  end

  resources do
    resource AshBoundary.Test.Blog.Post do
      define(:get_post, action: :read)
    end

    resource(AshBoundary.Test.Blog.Comment)
  end
end
