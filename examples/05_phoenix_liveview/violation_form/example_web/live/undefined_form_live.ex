defmodule ExampleWeb.UndefinedFormLive do
  @moduledoc """
  Proof that the web layer cannot build a form for an action that the domain does not declare.

  `Example.Post` has a real `:moderate` update action. `Example`'s `resources` block has no
  `define` for it, on purpose. The `AshPhoenix` extension generates a `form_to_<name>` function
  for each `define` on the domain, and only for those. `Example.form_to_moderate_post/1` therefore
  does not exist, and this module fails to compile.

  This failure differs in kind from the other modules in `violation/`. Those fail because
  `boundary` rejects a forbidden reference. This one fails because the function is not there at
  all. Both are compile-time failures, and this one needs no boundary configuration to work. It
  follows from the domain's `define` list being the only source of `form_to_*` functions.

  `ExampleWeb.PostLive` builds its form the correct way, with
  `Example.form_to_create_post(as: "post")`, because `define :create_post` exists.

  No normal build compiles this module. See `mix.exs` and
  `test/example_web/ash_violation_test.exs`.
  """

  use ExampleWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    # Violation: there is no `form_to_moderate_post` function on the domain, because the domain
    # declares no `define` for the `:moderate` action.
    {:ok, assign(socket, form: to_form(Example.form_to_moderate_post(as: "post")))}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.form for={@form} id="moderate-form" phx-submit="save"></.form>
    """
  end
end
