defmodule ExampleWeb.AshAliasReference do
  @moduledoc false

  # This is the violation:
  def query_module, do: Ash.Query
end
