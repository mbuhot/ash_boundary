defmodule AshBoundary.Test.Reports do
  @moduledoc """
  Fixture domain that is allowed to depend on `AshBoundary.Test.Blog`.

  Modules compiled into this namespace during a test may therefore reach
  `AshBoundary.Test.Blog.Post`, but not the unexported
  `AshBoundary.Test.Blog.Comment`.
  """

  use Ash.Domain, extensions: [AshBoundary.Test.Extension], validate_config_inclusion?: false

  boundary do
    deps([AshBoundary.Test.Blog])
  end

  resources do
  end
end

defmodule AshBoundary.Test.Isolated do
  @moduledoc """
  Fixture domain that declares no deps at all, so any reference it makes into
  `AshBoundary.Test.Blog` is a violation regardless of what `Blog` exports.
  """

  use Ash.Domain, extensions: [AshBoundary.Test.Extension], validate_config_inclusion?: false

  boundary do
    deps([])
  end

  resources do
  end
end
