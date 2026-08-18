defmodule AshBoundary.Test.Diamond.Sink do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  resources do
  end
end

defmodule AshBoundary.Test.Diamond.Left do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [AshBoundary.Test.Diamond.Sink]
  end

  resources do
  end
end

defmodule AshBoundary.Test.Diamond.Right do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [AshBoundary.Test.Diamond.Sink]
  end

  resources do
  end
end

defmodule AshBoundary.Test.Diamond.Source do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [
      AshBoundary.Test.Diamond.Left,
      AshBoundary.Test.Diamond.Right,
      AshBoundary.Test.Diamond.Sink
    ]
  end

  resources do
  end
end
