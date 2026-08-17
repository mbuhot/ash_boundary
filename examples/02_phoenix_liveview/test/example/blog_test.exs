defmodule Example.BlogTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(&Example.TestData.clear/0)
    Example.TestData.clear()

    %{author: Example.Accounts.register_author!("Mike Buhot", "mbuhot")}
  end

  test "the exported read action returns structs with calculations already loaded", %{
    author: author
  } do
    Example.Blog.create_post!(%{
      title: "Loaded by the domain",
      author_id: author.id,
      body: "A body long enough that the excerpt calculation has something to truncate."
    })

    [post] = Example.Blog.list_published_posts!()

    assert post.excerpt == "A body long enough that the excerpt calc..."
    assert post.word_count == 12
    refute match?(%Ash.NotLoaded{}, post.excerpt)
    refute match?(%Ash.NotLoaded{}, post.word_count)
  end

  test "the byline calculation reads through the accounts domain's interface", %{author: author} do
    Example.Blog.create_post!(%{title: "Attributed", author_id: author.id, body: "Body"})

    [post] = Example.Blog.list_published_posts!()

    assert post.byline == "Mike Buhot (@mbuhot)"
  end

  test "unpublished posts are filtered out by the read action, not by the caller", %{
    author: author
  } do
    Example.Blog.create_post!(%{
      title: "Draft",
      author_id: author.id,
      body: "Not ready",
      published?: false
    })

    Example.Blog.create_post!(%{title: "Live", author_id: author.id, body: "Ready"})

    assert ["Live"] == Enum.map(Example.Blog.list_published_posts!(), & &1.title)
    assert 2 == length(Example.Blog.list_posts!())
  end

  test "get_post_by_id/1 returns a post", %{author: author} do
    created = Example.Blog.create_post!(%{title: "Findable", author_id: author.id, body: "Here"})

    assert {:ok, post} = Example.Blog.get_post_by_id(created.id)
    assert post.title == "Findable"
    assert post.excerpt == "Here"
  end

  test "get_post_by_id/1 returns the Ash error the LiveView matches on" do
    assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
             Example.Blog.get_post_by_id(Ash.UUID.generate())
  end

  test "get_post_by_id/1 returns an invalid argument error for an unusable id" do
    assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.InvalidArgument{}]}} =
             Example.Blog.get_post_by_id("not-a-uuid")
  end

  test "the domain builds a form for a declared action" do
    form = Example.Blog.form_to_create_post(as: "post")

    assert form.resource == Example.Blog.Post
    assert form.action == :create
  end

  test "the boundary exports Post and depends on the accounts domain" do
    %{opts: opts} = AshBoundary.Declaration.definition(Example.Blog)

    assert opts[:exports] == [Post]
    assert opts[:deps] == [Example.Accounts]
  end
end
