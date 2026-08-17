defmodule ExampleWeb.PostLiveTest do
  @moduledoc """
  Proof that the happy path is a real, working LiveView and not just something that compiles.

  Each assertion here reads data that the LiveView obtained through `Example`'s exported
  functions and through `AshPhoenix.Form`. Those are the two things `ExampleWeb`'s boundary
  allows. No file in `lib/example_web/` holds an `Ash.*` reference.
  `ExampleWeb.AshViolationTest` is the companion proof, that the compiler rejects the forbidden
  alternatives.
  """

  use ExampleWeb.ConnCase, async: false

  setup do
    on_exit(&clear_posts/0)
    clear_posts()
    :ok
  end

  test "renders posts read through the domain, with calculations the domain loaded", %{conn: conn} do
    Example.create_post!(%{
      title: "Boundaries for Ash domains",
      author: "mbuhot",
      body: "A body long enough that the excerpt calculation has something to truncate."
    })

    {:ok, _live, html} = live(conn, "/")

    assert html =~ "1 published"
    assert html =~ "Boundaries for Ash domains"
    assert html =~ "by mbuhot"
    # The excerpt calculation, truncated at 40 bytes by
    # `Example.Post.Calculations.Excerpt`, and the `expr/1` word count. Neither is loaded
    # by default; both arrive loaded because the read action prepares them.
    assert html =~ "A body long enough that the excerpt calc..."
    assert html =~ "12 words"
  end

  test "unpublished posts do not render", %{conn: conn} do
    Example.create_post!(%{
      title: "Draft post",
      author: "mbuhot",
      body: "x",
      published?: false
    })

    {:ok, _live, html} = live(conn, "/")

    assert html =~ "0 published"
    refute html =~ "Draft post"
  end

  test "selecting a post renders it from a plain-data domain result", %{conn: conn} do
    post =
      Example.create_post!(%{title: "Selectable", author: "mbuhot", body: "Two words here"})

    {:ok, live, _html} = live(conn, "/")

    html = live |> element("#post-#{post.id} button") |> render_click()

    assert html =~ "Selected: Selectable"
    assert html =~ "(3 words)"
  end

  test "submitting the form persists a post through the domain", %{conn: conn} do
    {:ok, live, _html} = live(conn, "/")

    html =
      live
      |> form("#post-form",
        post: %{title: "Written from a form", author: "mbuhot", body: "Body text"}
      )
      |> render_submit()

    assert html =~ "Post published"
    assert html =~ "Written from a form"
    assert html =~ "1 published"

    # And it really is in the domain, not just on the page.
    assert ["Written from a form"] == Example.published_post_titles()
  end

  test "submitting invalid input renders validation errors as plain strings", %{conn: conn} do
    {:ok, live, _html} = live(conn, "/")

    html =
      live
      |> form("#post-form", post: %{title: "", author: "", body: ""})
      |> render_submit()

    # `AshPhoenix.Form.submit/2` returned `{:error, form}`. That is a form, not an
    # `%Ash.Error{}`. The errors reach the template as `{message, opts}` tuples, which is what
    # `ExampleWeb.CoreComponents.translate_error/1` already renders.
    assert html =~ "is required"
    assert Example.published_post_titles() == []
  end

  test "live validation reports errors before submission", %{conn: conn} do
    {:ok, live, _html} = live(conn, "/")

    html =
      live
      |> form("#post-form", post: %{title: "ok", author: "", body: ""})
      |> render_change()

    assert html =~ "is required"
  end

  defp clear_posts do
    Enum.each(Example.list_posts!(), &Example.delete_post!/1)
  end
end
