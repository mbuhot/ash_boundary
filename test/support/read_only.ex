defmodule AshBoundary.Test.Ledger.Entry do
  @moduledoc false
  use Ash.Resource, domain: AshBoundary.Test.Ledger

  attributes do
    uuid_primary_key(:id)
  end

  relationships do
    belongs_to(:post, AshBoundary.Test.Blog.Post, writable?: false)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshBoundary.Test.Ledger.Adjustment do
  @moduledoc false
  use Ash.Resource, domain: AshBoundary.Test.Ledger

  attributes do
    uuid_primary_key(:id)
  end

  relationships do
    belongs_to(:tag, AshBoundary.Test.Blog.Tag)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshBoundary.Test.Ledger do
  @moduledoc """
  Fixture domain permitting read-only relationships, with no `deps` entry on
  `Blog`.

  `Entry` reaches the exported `Blog.Post` with `writable?: false`, and
  `Adjustment` reaches the exported `Blog.Tag` writably. Only the first is
  exempt, so one domain covers both sides of the rule.
  """

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    allow_read_only_relationships? true
  end

  resources do
    resource(AshBoundary.Test.Ledger.Entry)
    resource(AshBoundary.Test.Ledger.Adjustment)
  end
end

defmodule AshBoundary.Test.Register.Line do
  @moduledoc false
  use Ash.Resource, domain: AshBoundary.Test.Register

  attributes do
    uuid_primary_key(:id)
  end

  relationships do
    belongs_to(:post, AshBoundary.Test.Blog.Post, writable?: false)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshBoundary.Test.Register do
  @moduledoc """
  Fixture domain with the same read-only relationship as `Ledger.Entry` and
  without `allow_read_only_relationships?`, so the reference stays a violation.
  """

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  resources do
    resource(AshBoundary.Test.Register.Line)
  end
end
