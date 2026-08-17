defmodule ExampleWeb.AshReadLive do
  @moduledoc """
  The violation this whole example exists to catch: a LiveView that runs its own Ash query
  instead of calling the domain.

  No normal build compiles this module. `mix.exs` adds `violation/` to `elixirc_paths` under
  `MIX_ENV=violation` only. `test/example_web/ash_violation_test.exs` shells out to that build
  and asserts the failure and the warnings below.

  There are two temptations here, one for each line:

    * `Ash.read!/1`: "I only want a list, so why go through the domain?"
    * `Ash.Query.filter/2`: "I only want to narrow the result a little."

  Both are calls into the `:ash` application. `ExampleWeb`'s `type: :strict` boundary does not
  list that application in its `deps`. Note what is correct in this module. `Example`
  exports `Example.Post`, so the code can name the resource. `use ExampleWeb, :live_view`
  is also correct. Only the two `Ash.*` calls are forbidden. They stay forbidden however
  reasonable they look.
  """

  use ExampleWeb, :live_view

  # `Ash.Query.filter/2` is a macro, so this `require` is needed for the code below to be
  # valid Elixir at all. It matters that these modules are *otherwise correct* code: the point
  # is that `boundary` rejects them, not that they fail to compile for some unrelated reason.
  require Ash.Query

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    # Violation 1: a raw read, bypassing `Example.list_published_posts!/0`.
    posts = Ash.read!(Example.Post)

    # Violation 2: building a query in the web layer, which is how a domain's filtering
    # rules end up duplicated in a template.
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
