defmodule ExampleWeb.PostLiveTest do
  use ExampleWeb.ConnCase, async: false

  setup do
    on_exit(&Example.TestData.clear/0)
    Example.TestData.clear()

    %{author: Example.Accounts.register_author!("Mike Buhot", "mbuhot")}
  end

  test "renders posts read through the domain, with calculations the domain loaded", %{
    conn: conn,
    author: author
  } do
    Example.Blog.create_post!(%{
      title: "Boundaries for Ash domains",
      author_id: author.id,
      body: "A body long enough that the excerpt calculation has something to truncate."
    })

    {:ok, _live, html} = live(conn, "/")

    assert html =~ "1 published"
    assert html =~ "Boundaries for Ash domains"
    assert html =~ "by Mike Buhot (@mbuhot)"
    assert html =~ "A body long enough that the excerpt calc..."
    assert html =~ "12 words"
  end

  test "renders the contributors read from the accounts domain", %{conn: conn, author: author} do
    {:ok, live, html} = live(conn, "/")

    assert html =~ "Mike Buhot (@mbuhot)"
    assert has_element?(live, "#author-#{author.id}")
  end

  test "unpublished posts do not render", %{conn: conn, author: author} do
    Example.Blog.create_post!(%{
      title: "Draft post",
      author_id: author.id,
      body: "x",
      published?: false
    })

    {:ok, _live, html} = live(conn, "/")

    assert html =~ "0 published"
    refute html =~ "Draft post"
  end

  test "selecting a post renders it from a plain-data domain result", %{
    conn: conn,
    author: author
  } do
    post =
      Example.Blog.create_post!(%{
        title: "Selectable",
        author_id: author.id,
        body: "Two words here"
      })

    {:ok, live, _html} = live(conn, "/")

    html = live |> element("#post-#{post.id} button") |> render_click()

    assert html =~ "Selected: Selectable"
    assert html =~ "(3 words)"
  end

  test "submitting the form persists a post through the domain", %{conn: conn, author: author} do
    {:ok, live, _html} = live(conn, "/")

    html =
      live
      |> form("#post-form",
        post: %{title: "Written from a form", author_id: author.id, body: "Body text"}
      )
      |> render_submit()

    assert html =~ "Post published"
    assert html =~ "Written from a form"
    assert html =~ "1 published"

    assert ["Written from a form"] ==
             Enum.map(Example.Blog.list_published_posts!(), & &1.title)
  end

  test "submitting invalid input renders validation errors as plain strings", %{conn: conn} do
    {:ok, live, _html} = live(conn, "/")

    html =
      live
      |> form("#post-form", post: %{title: "", author_id: "", body: ""})
      |> render_submit()

    assert html =~ "is required"
    assert Example.Blog.list_published_posts!() == []
  end

  test "live validation reports errors before submission", %{conn: conn} do
    {:ok, live, _html} = live(conn, "/")

    html =
      live
      |> form("#post-form", post: %{title: "ok", author_id: "", body: ""})
      |> render_change()

    assert html =~ "is required"
  end
end
