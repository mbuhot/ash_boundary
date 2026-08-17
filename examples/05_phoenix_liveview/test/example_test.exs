defmodule ExampleTest do
  @moduledoc """
  The domain side of the contract `ExampleWeb` depends on: read actions hand back fully
  loaded structs, and failures come back as plain data.

  Both properties are what let the web layer live without any `Ash.*` reference at all, so
  they are worth asserting directly rather than only through the LiveView.
  """

  use ExUnit.Case, async: false

  setup do
    # `Example.Post` uses a shared ETS table, with `private? false`. A web request runs in a
    # different process from the one that wrote the data. These tests therefore clear the table
    # explicitly, through the exported domain interface, like every other caller.
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

    # Ash loads neither field by default. They hold values because `:list_published` carries
    # `prepare build(load: [:excerpt, :word_count])`. That preparation is the reason
    # `ExampleWeb.PostLive` never needs `Ash.load/2`.
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
    # This is the function `ExampleWeb.PostLive` deliberately does *not* call, and
    # `violation/example_web/live/ash_error_match_live.ex` proves matching on this shape from
    # the web layer is a boundary violation. Asserting it here documents that the difference
    # between the two functions is real and not hypothetical.
    assert {:error, %Ash.Error.Invalid{}} = Example.get_post_by_id(Ash.UUID.generate())
  end

  test "published_post_titles/0 returns plain strings" do
    Example.create_post!(%{title: "Plain data", author: "mbuhot", body: "Strings only"})

    assert ["Plain data"] == Example.published_post_titles()
  end

  test "the domain generates a form builder for each define, and only for those" do
    # `define :create_post` produced this one. `ExampleWeb.PostLive` calls it, so the web layer
    # never names `Example.Post` to build a form.
    assert function_exported?(Example, :form_to_create_post, 0)
    assert function_exported?(Example, :form_to_create_post, 1)

    # `Example.Post`'s `:moderate` update action has no `define`, so it has no form builder. This
    # is what stops the web layer from building a form for an action the domain never declared.
    # `violation_form/example_web/live/undefined_form_live.ex` proves the compile-time half.
    refute Enum.any?(Example.__info__(:functions), fn {name, _arity} ->
             name == :form_to_moderate_post
           end)

    # The builder returns a form bound to the resource and action, so nothing downstream has to
    # name either one.
    form = Example.form_to_create_post(as: "post")
    assert form.resource == Example.Post
    assert form.action == :create
  end

  test "the undeclared :moderate action still exists on the resource" do
    # The point of the test above is not that `:moderate` is missing. It is a real action, and the
    # domain simply does not expose it. Without this assertion the previous test would also pass
    # for a resource with no such action at all.
    assert Enum.any?(Ash.Resource.Info.actions(Example.Post), &(&1.name == :moderate))
  end

  defp clear_posts do
    Enum.each(Example.list_posts!(), &Example.delete_post!/1)
  end
end
