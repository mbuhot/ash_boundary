defmodule AshBoundary.Test.Analytics.Metric do
  @moduledoc false
  use Ash.Resource, domain: AshBoundary.Test.Analytics

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshBoundary.Test.Analytics do
  @moduledoc """
  Fixture domain independent of `Blog`, exporting its own resource. Exists so
  `AshBoundary.Test.Dashboard` can depend on two independent domains at once.
  """

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  resources do
    resource AshBoundary.Test.Analytics.Metric do
      define(:get_metric, action: :read)
    end
  end
end

defmodule AshBoundary.Test.Dashboard do
  @moduledoc """
  Fixture domain depending on two independent domains at once (`Blog` and
  `Analytics`), each contributing its own exported resource. Proves that `deps`
  and export computation compose correctly across more than a single dependency,
  rather than only ever having been exercised one dependency at a time.
  """

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [AshBoundary.Test.Blog, AshBoundary.Test.Analytics]
  end

  resources do
  end
end
