defmodule Example.AccountsTest do
  @moduledoc false

  use ExUnit.Case, async: false

  setup do
    on_exit(&Example.TestData.clear/0)
    Example.TestData.clear()
    :ok
  end

  test "list_authors/0 sorts by name and loads the display name" do
    Example.Accounts.create_author!(%{name: "Zoe", handle: "zoe"})
    Example.Accounts.create_author!(%{name: "Ada", handle: "ada"})

    assert ["Ada (@ada)", "Zoe (@zoe)"] ==
             Enum.map(Example.Accounts.list_authors!(), & &1.display_name)
  end

  test "invitations are reachable only through the domain's own functions" do
    before = Example.Accounts.pending_invitation_count()

    assert :ok == Example.Accounts.invite_author("someone@example.com")

    assert Example.Accounts.pending_invitation_count() == before + 1
  end

  test "invite_author/1 returns a plain string message for invalid input" do
    assert {:error, message} = Example.Accounts.invite_author(nil)
    assert is_binary(message)
  end

  test "the boundary exports Author and keeps Invitation internal" do
    %{opts: opts} = AshBoundary.Declaration.definition(Example.Accounts)

    assert opts[:exports] == [Author]
    assert opts[:deps] == []
  end
end
