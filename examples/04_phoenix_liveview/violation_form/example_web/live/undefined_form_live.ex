defmodule ExampleWeb.UndefinedFormLive do
  @moduledoc false

  use ExampleWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    # This is the violation:
    {:ok, assign(socket, form: to_form(Example.form_to_moderate_post(as: "post")))}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.form for={@form} id="moderate-form" phx-submit="save"></.form>
    """
  end
end
