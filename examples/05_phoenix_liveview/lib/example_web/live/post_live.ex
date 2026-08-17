defmodule ExampleWeb.PostLive do
  @moduledoc """
  The point of this example, in one module. This is a real LiveView. It reads and writes blog
  posts, and it never references the `:ash` application.

  Read this code beside `ExampleWeb`'s boundary declaration. Every line here is one of four
  things:

    * a call to `Example`, the exported domain module: `list_published_posts!/0` and
      `fetch_post/1`;
    * a field read on a `%Example.Post{}` struct, such as `post.title`, `post.excerpt`,
      and `post.word_count`, on a struct the domain returned already loaded;
    * a call to `AshPhoenix.Form` for live validation and submission of the form that the domain
      returned. That module lives in the separate `:ash_phoenix` application, which `ExampleWeb`
      lists as a dep;
    * ordinary Phoenix.

  This file cannot contain `Ash.read!/1`, `Ash.get!/2`, `Ash.load!/2`, `Ash.Query.filter/2`,
  or `%Ash.Error.Invalid{}`. Each one is a compile error here.
  `violation/example_web/live/` holds a module for each case, and
  `test/example_web/ash_violation_test.exs` compiles them under `MIX_ENV=violation`.

  Three details below are load-bearing, not stylistic:

    * `post.excerpt` and `post.word_count` are calculations. Ash does not load a calculation
      by default. The obvious way to get them into a template is `Ash.load!(post, :excerpt)`
      in `mount/3`. That call is forbidden here. The fix is not an exception. It is a one-line
      preparation on the read action. See the `:list_published` action on
      `Example.Post`, which loads both calculations in the domain so this module can read
      a field.

    * `handle_event("show", ...)` calls `Example.fetch_post/1`. It does not call the
      generated `Example.get_post_by_id/1`. Both functions exist and both are exported.
      The difference is the return value. The generated one returns
      `{:error, %Ash.Error.Invalid{}}` for a missing post, and `Ash.Error.Invalid` is a module
      in `:ash`. A match on it here fails to compile. `fetch_post/1` returns
      `{:error, :not_found}`, which is plain data.

    * The form errors arrive as `{message, opts}` tuples, a binary plus a keyword list. They
      come from `AshPhoenix.Form`'s `Phoenix.HTML.FormData` implementation, and
      `ExampleWeb.CoreComponents.translate_error/1` already expects that shape. This module
      matches no `Ash.Error` struct, even on the failure path.
  """

  use ExampleWeb, :live_view

  alias AshPhoenix.Form

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(selected: nil, lookup_error: nil)
     |> assign_posts()
     |> assign_new_form()}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"post" => params}, socket) do
    # Live validation, on every keystroke, entirely inside `:ash_phoenix`. This is the one
    # thing that genuinely cannot be done through a domain code interface: it needs the
    # changeset, not the result of running an action.
    {:noreply, assign(socket, form: Form.validate(socket.assigns.form, params))}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"post" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _post} ->
        # `{:ok, post}` hands back a `%Example.Post{}`. Note it is deliberately
        # discarded and the list re-read through the domain's exported read action, so
        # every struct this module renders has been through `:list_published`'s
        # `prepare build(load: [...])` and is fully loaded.
        {:noreply,
         socket
         |> put_flash(:info, "Post published")
         |> assign_posts()
         |> assign_new_form()}

      {:error, form} ->
        # `form`, not an `Ash.Error`. `AshPhoenix.Form.submit/2` returns the re-validated
        # form on failure, which is the entire reason the error path here needs no `:ash`
        # reference either.
        {:noreply, assign(socket, form: form)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("show", %{"id" => id}, socket) do
    case Example.fetch_post(id) do
      # This clause matches the resource struct itself, not just a tuple. That match is the first
      # of the two mechanisms in action: `Example` exports `Example.Post`, so this module can name
      # it. Delete the `define`s from the domain's `resources` block and this line stops
      # compiling.
      {:ok, %Example.Post{} = post} ->
        {:noreply, assign(socket, selected: post, lookup_error: nil)}

      {:error, :not_found} ->
        {:noreply, assign(socket, selected: nil, lookup_error: "No such post")}

      {:error, message} ->
        {:noreply, assign(socket, selected: nil, lookup_error: message)}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1 id="heading">Blog posts</h1>

      <p id="count">{length(@posts)} published</p>

      <ul id="posts">
        <li :for={post <- @posts} id={"post-#{post.id}"}>
          <h2>{post.title}</h2>
          <p class="author">by {post.author}</p>
          <p class="excerpt">{post.excerpt}</p>
          <p class="word-count">{post.word_count} words</p>
          <button phx-click="show" phx-value-id={post.id}>Show</button>
        </li>
      </ul>

      <div :if={@selected} id="selected">
        Selected: {@selected.title} ({@selected.word_count} words)
      </div>

      <div :if={@lookup_error} id="lookup-error">{@lookup_error}</div>

      <.form for={@form} id="post-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:title]} type="text" label="Title" />
        <.input field={@form[:author]} type="text" label="Author" />
        <.input field={@form[:body]} type="textarea" label="Body" />
        <button type="submit">Publish</button>
      </.form>
    </Layouts.app>
    """
  end

  # Reads through the exported domain code interface, and through nothing else. The `!` variant
  # raises on failure, which is acceptable here. A raised exception is a runtime value, not a
  # compile-time reference. So this file names no `Ash.*` module, even though `:ash` defines the
  # exception it would raise.
  defp assign_posts(socket), do: assign(socket, posts: Example.list_published_posts!())

  # The domain builds the form. `Example.form_to_create_post/1` is generated by the `AshPhoenix`
  # extension from the `define :create_post` entry in `Example`'s `resources` block, and it
  # returns an `%AshPhoenix.Form{}` already bound to the right resource and action.
  #
  # This module therefore never names `Example.Post` to construct a form, and it cannot build a
  # form for an action the domain did not declare. `Example.Post`'s `:moderate` action has no
  # `define`, so no `form_to_moderate_post/1` function exists at all. See
  # `violation_form/example_web/live/undefined_form_live.ex`.
  defp assign_new_form(socket) do
    assign(socket, form: to_form(Example.form_to_create_post(as: "post")))
  end
end
