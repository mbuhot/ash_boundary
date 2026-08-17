defmodule Example.AccountsTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(&Example.TestData.clear/0)
    Example.TestData.clear()
    :ok
  end

  test "contributors/0 returns plain maps, sorted by name" do
    Example.Accounts.register_author!("Zoe", "zoe")
    Example.Accounts.register_author!("Ada", "ada")

    assert ["Ada (@ada)", "Zoe (@zoe)"] ==
             Enum.map(Example.Accounts.contributors!(), & &1.display_name)
  end

  test "author_bylines/1 returns display names for the ids it is given" do
    author = Example.Accounts.register_author!("Ada", "ada")

    assert %{} = bylines = Example.Accounts.author_bylines!([author.id])
    assert bylines[author.id] == "Ada (@ada)"
  end

  test "inviting an author counts against the internal invitation resource" do
    author = Example.Accounts.register_author!("Ada", "ada")

    assert author.pending_invitations == 0

    assert %{pending_invitations: 1} =
             Example.Accounts.invite_author!(author.id, "someone@example.com")
  end

  test "the code interface returns an Ash error for an unknown author" do
    assert {:error, %Ash.Error.Invalid{}} =
             Example.Accounts.invite_author(Ash.UUID.generate(), "someone@example.com")
  end

  test "the boundary exports Directory and keeps Author and Invitation internal" do
    %{opts: opts} = AshBoundary.Declaration.definition(Example.Accounts)

    assert opts[:exports] == [Directory]
    assert opts[:deps] == []
  end
end
