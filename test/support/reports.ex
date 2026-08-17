defmodule AshBoundary.Test.Reports do
  @moduledoc """
  Fixture domain that is allowed to depend on `AshBoundary.Test.Blog`.

  Modules compiled into this namespace during a test may therefore reach
  `AshBoundary.Test.Blog.Post`, but not the unexported
  `AshBoundary.Test.Blog.Comment`.
  """

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [AshBoundary.Test.Blog]
  end

  resources do
  end
end

defmodule AshBoundary.Test.Isolated do
  @moduledoc """
  Fixture domain with no `boundary` section at all, so any reference it makes into
  `AshBoundary.Test.Blog` is a violation regardless of what `Blog` exports.
  """

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  resources do
  end
end

defmodule AshBoundary.Test.Archive do
  @moduledoc """
  Fixture domain using the `{module, :compile}` form of a `deps` entry, which narrows the
  dependency to compile-time references only rather than widening a bare one.
  """

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [{AshBoundary.Test.Blog, :compile}]
  end

  resources do
  end
end
