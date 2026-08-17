defmodule ExampleWeb.AshViolationTest do
  @moduledoc """
  The automated half of this example's claim. `ExampleWeb.PostLiveTest` proves the allowed
  path really works; this proves the forbidden paths really are rejected, on every `mix test`
  run, rather than leaving the reader to reproduce it by hand.

  It shells out to a real, separate `mix compile --warnings-as-errors` against
  `MIX_ENV=violation` (see `mix.exs`: that env alone adds `violation/` to `elixirc_paths`, so
  it is the only build that ever compiles the deliberately-coupled modules) and asserts on the
  real exit code and real captured output.

  Why a subprocess rather than something in-process like `Code.compile_file/1`: `boundary`'s
  forbidden-reference check is wired in as a Mix *compiler*
  (`compilers: [:boundary, ...] ++ Mix.compilers()`), not a check inside the modules being
  compiled, so only a real `mix compile` run invokes it. This is the same technique
  `examples/04_deliberate_violation` uses, for the same reason.

  The first run against a fresh checkout has to compile this project's dependencies for the
  `:violation` env from scratch. That includes `ash`, `phoenix`, and `ash_phoenix`, and it takes
  a few minutes. Every later run reuses `_build/violation/` and is fast. The timeout below allows
  for the first run.
  """

  use ExUnit.Case, async: false

  @moduletag timeout: :timer.minutes(10)

  # One entry per way the web layer can reach for Ash, with the real warning `boundary` emits.
  # `Ash.*` calls and `%Ash.Error.Invalid{}` struct expansion are reported identically: as a
  # forbidden reference from the boundary to a module in an application the boundary does not
  # depend on.
  @expected_warnings [
    # A raw read, instead of the domain's exported read action.
    """
    warning: forbidden reference to Ash
      (references from ExampleWeb to Ash are not allowed)
      violation/example_web/live/ash_read_live.ex:32\
    """,
    # Building a query in the web layer.
    """
    warning: forbidden reference to Ash.Query
      (references from ExampleWeb to Ash.Query are not allowed)
      violation/example_web/live/ash_read_live.ex:38\
    """,
    # `Ash.load/2` on a struct the domain already returned. This is the sympathetic case, and it
    # stays forbidden. The fix is a preparation on the domain's read action. See the README.
    """
    warning: forbidden reference to Ash
      (references from ExampleWeb to Ash are not allowed)
      violation/example_web/live/ash_load_live.ex:29\
    """,
    # Pattern-matching an Ash error struct, which is why domain functions translate errors to
    # plain data.
    """
    warning: forbidden reference to Ash.Error.Invalid
      (references from ExampleWeb to Ash.Error.Invalid are not allowed)
      violation/example_web/live/ash_error_match_live.ex:38\
    """,
    # A reference that only names a module and calls nothing. Plain `type: :strict` does not catch
    # this one, because `boundary` defaults to `check: [aliases: false]`. `ExampleWeb` sets
    # `check: [aliases: true]`, which is what makes it a violation. See
    # `ExampleWeb.AshAliasReference`.
    """
    warning: forbidden reference to Ash.Query
      (references from ExampleWeb to Ash.Query are not allowed)
      violation/example_web/live/ash_alias_reference.ex:23\
    """
  ]

  test "MIX_ENV=violation mix compile --warnings-as-errors fails, catching every route from the web layer into :ash" do
    {output, exit_code} = compile(["compile", "--warnings-as-errors"])

    assert exit_code == 1,
           "expected `MIX_ENV=violation mix compile --warnings-as-errors` to fail (exit 1) " <>
             "because it compiles genuine boundary violations, but it exited #{exit_code}. " <>
             "Full output:\n\n#{output}"

    for warning <- @expected_warnings do
      assert output =~ warning,
             "expected this warning in the output:\n\n#{warning}\n\nFull output:\n\n#{output}"
    end
  end

  test "MIX_ENV=violation mix compile (without --warnings-as-errors) still reports the violations but exits 0" do
    {output, exit_code} = compile(["compile", "--force"])

    assert exit_code == 0,
           "boundary reports violations as warnings, not hard failures, without " <>
             "--warnings-as-errors. Expected exit 0. Full output:\n\n#{output}"

    assert output =~ "forbidden reference to Ash"
  end

  test "MIX_ENV=undefined_form mix compile --warnings-as-errors fails, because the domain declares no form builder for an undeclared action" do
    {output, exit_code} = compile(["compile", "--warnings-as-errors"], "undefined_form")

    assert exit_code == 1,
           "expected `MIX_ENV=undefined_form mix compile --warnings-as-errors` to fail (exit 1). " <>
             "Full output:\n\n#{output}"

    # `Example.Post` has a real `:moderate` update action, and `Example` declares no `define` for
    # it. The `AshPhoenix` extension generates a `form_to_<name>` function for each `define`, and
    # only for those. So the web layer cannot build a form for `:moderate` at all.
    assert output =~ "Example.form_to_moderate_post/1 is undefined or private"

    # The same message lists the form builders that do exist, which is the positive half of the
    # proof: `define :create_post` produced `form_to_create_post`, and the `:moderate` action
    # produced nothing.
    assert output =~ "form_to_create_post/1"

    # This failure is an ordinary Elixir undefined-function warning, not a `boundary` diagnostic.
    # That difference is why this fixture needs its own env. Under `--warnings-as-errors` the
    # warning fails the app compile, and `boundary` runs its checks only after a successful app
    # compile.
    refute output =~ "forbidden reference"
  end

  defp compile(args, env \\ "violation") do
    System.cmd("mix", args,
      cd: File.cwd!(),
      env: [{"MIX_ENV", env}],
      stderr_to_stdout: true
    )
  end
end
