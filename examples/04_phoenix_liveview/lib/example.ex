defmodule Example do
  @moduledoc """
  The application's root boundary.
  """

  use Boundary, deps: [Example.Accounts, Example.Blog, ExampleWeb]
end
