defmodule ExampleWeb.AshAliasReference do
  @moduledoc """
  The violation that plain `type: :strict` does not catch on its own, and the reason
  `ExampleWeb` also sets `check: [aliases: true]`.

  This module calls no function in `:ash`. It only names `Ash.Query` and hands the module back as
  a value. A caller can then reach Ash through that value, with `apply/3` for example, and no
  `Ash.*` call ever appears in the web layer's source.

  `boundary` classifies this as an alias reference. Its documented default is
  `check: [aliases: false]`, which does not check such a reference. Verified in both directions:
  with the default, this module compiles clean under `type: :strict`; with
  `check: [aliases: true]`, `boundary` reports it. AshBoundary turns alias checking on for every
  domain it manages, and `ExampleWeb` matches that posture, so the reference below is a violation.

  No normal build compiles this module. See `mix.exs` and
  `test/example_web/ash_violation_test.exs`.
  """

  @doc """
  Returns the `Ash.Query` module itself. This is the violation.
  """
  def query_module, do: Ash.Query
end
