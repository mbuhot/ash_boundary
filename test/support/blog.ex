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

defmodule AshBoundary.Test.Blog.Draft do
  @moduledoc false
  use Ash.Resource, domain: AshBoundary.Test.Blog

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshBoundary.Test.Blog.Tag do
  @moduledoc false
  use Ash.Resource, domain: AshBoundary.Test.Blog

  code_interface do
    define(:list_tags, action: :read)
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

  `Draft` has no code interface at all, neither on the domain nor the resource — an
  even more basic case of "no domain-level define" than `Comment`, and stays internal
  the same way.

  `Tag` has both: a domain-level `define` (making it exported) and its own
  resource-level `code_interface` (making it independently callable as
  `Blog.Tag.list_tags/0`) — proving the two are not mutually exclusive.
  """

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  resources do
    resource AshBoundary.Test.Blog.Post do
      define(:get_post, action: :read)
    end

    resource(AshBoundary.Test.Blog.Comment)
    resource(AshBoundary.Test.Blog.Draft)

    resource AshBoundary.Test.Blog.Tag do
      define(:get_tag, action: :read)
    end
  end
end
