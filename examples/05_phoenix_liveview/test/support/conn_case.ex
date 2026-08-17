defmodule ExampleWeb.ConnCase do
  @moduledoc """
  The test case for tests that need a connection, as `mix phx.new` generates it (minus the
  Ecto sandbox setup, since this example has no Ecto).

  It is worth knowing why this module is interesting under `ExampleWeb`'s `type: :strict`
  boundary. It lives in `test/support/`, which `mix.exs` adds to `elixirc_paths` in `:test`
  only. Its name is `ExampleWeb.ConnCase`, so it lands inside the strict boundary. `boundary`
  therefore checks its references to `ExUnit.CaseTemplate`, `Phoenix.ConnTest`, and
  `Phoenix.LiveViewTest` like any others. Those modules serve tests only, so they get the same
  env-conditional treatment that `Phoenix.LiveReloader` gets for `:dev`. See the `deps` list in
  `ExampleWeb`, where the entries appear inline rather than in a module attribute.

  There is an alternative. You can write these imports inline in each test file. `mix test`
  loads `test/**/*.exs` files rather than compiling them with `mix compile`, so `boundary` never
  sees their references. That fact is worth knowing. It is not a reason to avoid a shared case.
  An env-scoped dependency is an ordinary thing to declare.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint ExampleWeb.Endpoint

      use ExampleWeb, :verified_routes

      # Import conveniences for testing with connections
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
