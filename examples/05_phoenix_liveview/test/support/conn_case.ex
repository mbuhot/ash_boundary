defmodule ExampleWeb.ConnCase do
  @moduledoc false

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
