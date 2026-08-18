defmodule AshBoundary.Test.Fulfilment.Shipment do
  @moduledoc false
  use Ash.Resource, domain: AshBoundary.Test.Fulfilment

  attributes do
    uuid_primary_key(:id)
  end

  relationships do
    belongs_to(:order, AshBoundary.Test.Orders.Order, writable?: false)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshBoundary.Test.Fulfilment do
  @moduledoc """
  Fixture domain holding the read-only half of a two-way relationship with
  `Orders`, declared without a `deps` entry so the pair is not a cycle.

  Lives in its own file: two domains that reach each other have to be compiled
  as separate units, the same as they would be in an application.
  """

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    allow_read_only_relationships? true
  end

  resources do
    resource AshBoundary.Test.Fulfilment.Shipment do
      define(:get_shipment, action: :read)
    end
  end
end
