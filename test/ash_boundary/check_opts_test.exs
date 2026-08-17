defmodule AshBoundary.CheckOptsTest do
  @moduledoc """
  Covers `AshBoundary.Declaration.check_opts/0`'s reading of the project-level
  `boundary: [default: [check: ...]]` config.

  Not async: the only honest way to test what a function reads out of
  `Mix.Project.config/0` is to put a different project on the project stack, which is
  global. ExUnit runs sync modules after every async one has finished, so no other test
  observes the swapped project.
  """

  use ExUnit.Case, async: false

  alias AshBoundary.Declaration

  defmodule ProjectWithCheckApps do
    @moduledoc false
    def project,
      do: [app: :ash_boundary, boundary: [default: [check: [apps: [:some_app]]]]]
  end

  defmodule ProjectOptingOutOfAliases do
    @moduledoc false
    def project,
      do: [app: :ash_boundary, boundary: [default: [check: [aliases: false, apps: [:some_app]]]]]
  end

  defmodule ProjectWithoutBoundaryConfig do
    @moduledoc false
    def project, do: [app: :ash_boundary]
  end

  test "an app's own project-level check config survives, rather than being clobbered" do
    # The failure this guards against is specific and silent. `Boundary.Definition` merges
    # the project-level default into a boundary's own options with a *shallow* `Map.merge`,
    # so a per-boundary `check:` replaces the project-level one outright. Had AshBoundary
    # passed a bare `check: [aliases: true]`, this app's `apps: [:some_app]` would have
    # vanished — for AshBoundary domains only, and with no error anywhere.
    in_project(ProjectWithCheckApps, fn ->
      assert Declaration.check_opts() == [aliases: true, apps: [:some_app]]
    end)
  end

  test "an explicit project-level `aliases: false` is respected, not forced back on" do
    in_project(ProjectOptingOutOfAliases, fn ->
      assert Declaration.check_opts() == [aliases: false, apps: [:some_app]]
    end)
  end

  test "with no project-level config at all, alias checking is the default" do
    in_project(ProjectWithoutBoundaryConfig, fn ->
      assert Declaration.check_opts() == [aliases: true]
    end)
  end

  defp in_project(module, fun) do
    Mix.Project.push(module)

    try do
      fun.()
    after
      Mix.Project.pop()
    end
  end
end
