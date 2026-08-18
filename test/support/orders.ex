defmodule AshBoundary.Test.Orders.Order do
  @moduledoc false
  use Ash.Resource, domain: AshBoundary.Test.Orders

  attributes do
    uuid_primary_key(:id)
  end

  relationships do
    belongs_to(:shipment, AshBoundary.Test.Fulfilment.Shipment)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshBoundary.Test.Orders do
  @moduledoc """
  Fixture domain holding the writable half of a two-way relationship with
  `Fulfilment`, and the only half that declares a `deps` entry.
  """

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [AshBoundary.Test.Fulfilment]
  end

  resources do
    resource AshBoundary.Test.Orders.Order do
      define(:get_order, action: :read)
    end
  end
end
