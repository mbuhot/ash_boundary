defmodule AshBoundary.Test.CompileDeps.Base do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  resources do
  end
end

defmodule AshBoundary.Test.CompileDeps.Middle do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [{AshBoundary.Test.CompileDeps.Base, :compile}]
  end

  resources do
  end
end

defmodule AshBoundary.Test.CompileDeps.CompilePath do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [
      {AshBoundary.Test.CompileDeps.Middle, :compile},
      {AshBoundary.Test.CompileDeps.Base, :compile}
    ]
  end

  resources do
  end
end

defmodule AshBoundary.Test.CompileDeps.RuntimeMiddle do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [AshBoundary.Test.CompileDeps.Base]
  end

  resources do
  end
end

defmodule AshBoundary.Test.CompileDeps.RuntimePath do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [
      AshBoundary.Test.CompileDeps.RuntimeMiddle,
      {AshBoundary.Test.CompileDeps.Base, :compile}
    ]
  end

  resources do
  end
end

defmodule AshBoundary.Test.CompileDeps.MixedPath do
  @moduledoc false

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [{AshBoundary.Test.CompileDeps.Middle, :compile}, AshBoundary.Test.CompileDeps.Base]
  end

  resources do
  end
end
