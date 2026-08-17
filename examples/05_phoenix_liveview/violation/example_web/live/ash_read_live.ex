defmodule ExampleWeb.AshReadLive do
  @moduledoc false

  use ExampleWeb, :live_view

  require Ash.Query

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    # This is the violation:
    posts = Ash.read!(Example.Post)

    # This is the violation:
    published =
      Example.Post
      |> Ash.Query.filter(published? == true)
      |> Ash.read!()

    {:ok, assign(socket, posts: posts, published: published)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <p>{length(@posts)} posts, {length(@published)} published</p>
    """
  end
end
