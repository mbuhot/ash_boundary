defmodule ExampleWeb.AshErrorMatchLive do
  @moduledoc false

  use ExampleWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, error: nil, post: nil)}
  end

  @impl Phoenix.LiveView
  def handle_event("show", %{"id" => id}, socket) do
    case Example.get_post_by_id(id) do
      {:ok, post} ->
        {:noreply, assign(socket, post: post, error: nil)}

      # This is the violation:
      {:error, %Ash.Error.Invalid{}} ->
        {:noreply, assign(socket, post: nil, error: "not found")}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <p>{@error}</p>
    """
  end
end
