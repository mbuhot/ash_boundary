defmodule ExampleWeb.AshViolationTest do
  use ExUnit.Case, async: false

  @moduletag timeout: :timer.minutes(10)

  @expected_warnings [
    """
    warning: forbidden reference to Ash
      (references from ExampleWeb to Ash are not allowed)
      violation/example_web/live/ash_read_live.ex:11\
    """,
    """
    warning: forbidden reference to Ash.Query
      (references from ExampleWeb to Ash.Query are not allowed)
      violation/example_web/live/ash_read_live.ex:16\
    """,
    """
    warning: forbidden reference to Ash
      (references from ExampleWeb to Ash are not allowed)
      violation/example_web/live/ash_load_live.ex:11\
    """,
    """
    warning: forbidden reference to Ash.Error.Invalid
      (references from ExampleWeb to Ash.Error.Invalid are not allowed)
      violation/example_web/live/ash_error_match_live.ex:18\
    """,
    """
    warning: forbidden reference to Ash.Query
      (references from ExampleWeb to Ash.Query are not allowed)
      violation/example_web/live/ash_alias_reference.ex:5\
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

    assert output =~ "Example.form_to_moderate_post/1 is undefined or private"

    assert output =~ "form_to_create_post/1"

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
