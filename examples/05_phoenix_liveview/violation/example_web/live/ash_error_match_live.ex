defmodule ExampleWeb.AshErrorMatchLive do
  @moduledoc """
  The error-path violation, and the reason `Example.fetch_post/1` exists.

  This LiveView calls `Example.get_post_by_id/1`. That function is real, generated, and
  exported, so the call itself is allowed. The LiveView then matches the error it returns. That
  error is `%Ash.Error.Invalid{}`, a struct in the `:ash` application. The `case` clause below
  is therefore a forbidden reference, even though this file calls no `Ash` function.

  This behaviour makes "the domain returns plain data" a boundary concern, not a style
  preference. A function that returns an `Ash.Error` forces each caller to reference `:ash` to
  handle a failure. Under this boundary the web layer therefore cannot use that function.
  `Example.fetch_post/1` translates the same failure into `{:error, :not_found}`.
  `ExampleWeb.PostLive` matches that value with no reference into `:ash`.

  `boundary` checks struct expansion even though it does not check a plain alias reference by
  default. The documented default is `check: [aliases: false]`. `ExampleWeb` turns alias
  checking on as well, which matches what AshBoundary does for every domain it manages.

  Not compiled by any normal build; see `mix.exs` and
  `test/example_web/ash_violation_test.exs`.
  """

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

      # Violation: `%Ash.Error.Invalid{}` is a struct in the `:ash` application.
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
