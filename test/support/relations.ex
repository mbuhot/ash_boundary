defmodule AshBoundary.Test.Relations do
  @moduledoc """
  Fixture domain used to prove that *alias* references, unlike calls, are not checked
  by default.

  Its resources are compiled inside the test that needs them, so that `boundary`'s own
  compiler tracer is installed and records the references — which is why the `resources`
  block here is empty. Those fixture resources pass `domain: nil`: what puts a module
  inside this boundary is `Boundary.Mix.Classifier`, which goes purely by module-name
  nesting and knows nothing about Ash, so `AshBoundary.Test.Relations.Ticket` belongs to
  this boundary whether or not Ash considers it part of this domain.

  `deps [AshBoundary.Test.Blog]` costs nothing to declare and matches what a real domain
  with a relationship into `Blog` would carry, even though an alias reference alone would
  compile the same way without it.
  """

  use Ash.Domain, extensions: [AshBoundary], validate_config_inclusion?: false

  boundary do
    deps [AshBoundary.Test.Blog]
  end

  resources do
  end
end
