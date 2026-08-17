defmodule AshBoundary.Test.Tooling do
  @moduledoc "Fixture boundary declared by hand with `use Boundary`, rather than by a domain."
  use Boundary
end

defmodule AshBoundary.Test.Ops do
  @moduledoc "Fixture domain whose only dep is a compile-time dep on a hand-written boundary."

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [{AshBoundary.Test.Tooling, :compile}]
  end

  resources do
  end
end
