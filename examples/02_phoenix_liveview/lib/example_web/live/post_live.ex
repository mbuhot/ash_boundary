defmodule ExampleWeb.PostLive do
  @moduledoc """
  LiveView for listing and creating blog posts.
  """

  use ExampleWeb, :live_view

  alias AshPhoenix.Form

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(selected: nil, lookup_error: nil)
     |> assign_posts()
     |> assign_contributors()
     |> assign_new_form()}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"post" => params}, socket) do
    {:noreply, assign(socket, form: Form.validate(socket.assigns.form, params))}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"post" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:info, "Post published")
         |> assign_posts()
         |> assign_new_form()}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("show", %{"id" => id}, socket) do
    case Example.Blog.get_post_by_id(id) do
      {:ok, %Example.Blog.Post{} = post} ->
        {:noreply, assign(socket, selected: post, lookup_error: nil)}

      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{} | _]}} ->
        {:noreply, assign(socket, selected: nil, lookup_error: "No such post")}

      {:error, error} ->
        {:noreply, assign(socket, selected: nil, lookup_error: Exception.message(error))}
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
          <p class="author">by {post.byline}</p>
          <p class="excerpt">{post.excerpt}</p>
          <p class="word-count">{post.word_count} words</p>
          <button phx-click="show" phx-value-id={post.id}>Show</button>
        </li>
      </ul>

      <div :if={@selected} id="selected">
        Selected: {@selected.title} ({@selected.word_count} words)
      </div>

      <div :if={@lookup_error} id="lookup-error">{@lookup_error}</div>

      <aside id="contributors">
        <h2>Contributors</h2>
        <ul>
          <li :for={contributor <- @contributors} id={"author-#{contributor.id}"}>
            {contributor.display_name} ({contributor.pending_invitations} invitations pending)
          </li>
        </ul>
      </aside>

      <.form for={@form} id="post-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:title]} type="text" label="Title" />
        <.input
          field={@form[:author_id]}
          type="select"
          prompt="Choose an author"
          options={author_options(@contributors)}
          label="Author"
        />
        <.input field={@form[:body]} type="textarea" label="Body" />
        <button type="submit">Publish</button>
      </.form>
    </Layouts.app>
    """
  end

  defp assign_posts(socket) do
    # Reading a resource through Ash is not allowed
    # assign(socket, posts: Ash.read!(Example.Blog.Post))
    assign(socket, posts: Example.Blog.list_published_posts!())
  end

  defp assign_contributors(socket) do
    assign(socket, contributors: Example.Accounts.contributors!())
  end

  defp author_options(contributors), do: Enum.map(contributors, &{&1.display_name, &1.id})

  defp assign_new_form(socket) do
    assign(socket, form: to_form(Example.Blog.form_to_create_post(as: "post")))
  end
end
