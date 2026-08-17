defmodule ExampleTest do
  use ExUnit.Case, async: false

  setup do
    on_exit(&clear_posts/0)
    clear_posts()
  end

  test "the exported read action returns structs with calculations already loaded" do
    Example.create_post!(%{
      title: "Loaded by the domain",
      author: "mbuhot",
      body: "A body long enough that the excerpt calculation has something to truncate."
    })

    [post] = Example.list_published_posts!()

    assert post.excerpt == "A body long enough that the excerpt calc..."
    assert post.word_count == 12
    refute match?(%Ash.NotLoaded{}, post.excerpt)
    refute match?(%Ash.NotLoaded{}, post.word_count)
  end

  test "unpublished posts are filtered out by the read action, not by the caller" do
    Example.create_post!(%{
      title: "Draft",
      author: "mbuhot",
      body: "Not ready",
      published?: false
    })

    Example.create_post!(%{title: "Live", author: "mbuhot", body: "Ready"})

    assert ["Live"] == Enum.map(Example.list_published_posts!(), & &1.title)
    assert 2 == length(Example.list_posts!())
  end

  test "fetch_post/1 returns a post" do
    created = Example.create_post!(%{title: "Findable", author: "mbuhot", body: "Here"})

    assert {:ok, post} = Example.fetch_post(created.id)
    assert post.title == "Findable"
    assert post.excerpt == "Here"
  end

  test "fetch_post/1 translates a missing post into :not_found, not an Ash error" do
    assert {:error, :not_found} = Example.fetch_post(Ash.UUID.generate())
  end

  test "fetch_post/1 translates an unusable id into a plain string message" do
    assert {:error, message} = Example.fetch_post("not-a-uuid")
    assert is_binary(message)
  end

  test "the generated code interface, by contrast, returns an Ash error struct" do
    assert {:error, %Ash.Error.Invalid{}} = Example.get_post_by_id(Ash.UUID.generate())
  end

  test "published_post_titles/0 returns plain strings" do
    Example.create_post!(%{title: "Plain data", author: "mbuhot", body: "Strings only"})

    assert ["Plain data"] == Example.published_post_titles()
  end

  test "the domain generates a form builder for each define, and only for those" do
    assert function_exported?(Example, :form_to_create_post, 0)
    assert function_exported?(Example, :form_to_create_post, 1)

    refute Enum.any?(Example.__info__(:functions), fn {name, _arity} ->
             name == :form_to_moderate_post
           end)

    form = Example.form_to_create_post(as: "post")
    assert form.resource == Example.Post
    assert form.action == :create
  end

  test "the undeclared :moderate action still exists on the resource" do
    assert Enum.any?(Ash.Resource.Info.actions(Example.Post), &(&1.name == :moderate))
  end

  defp clear_posts do
    Enum.each(Example.list_posts!(), &Example.delete_post!/1)
  end
end
