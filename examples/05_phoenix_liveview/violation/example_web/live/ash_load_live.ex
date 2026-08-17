defmodule ExampleWeb.AshLoadLive do
  @moduledoc false

  use ExampleWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    posts =
      Example.list_published_posts!()
      # This is the violation:
      |> Ash.load!(:excerpt)

    {:ok, assign(socket, posts: posts)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <p>{length(@posts)} posts</p>
    """
  end
end
