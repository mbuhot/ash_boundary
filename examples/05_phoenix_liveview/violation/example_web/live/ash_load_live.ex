defmodule ExampleWeb.AshLoadLive do
  @moduledoc """
  The most sympathetic violation in this directory, and the one worth arguing about: the
  LiveView has a perfectly good struct, handed over by the domain, and it just wants one more
  calculation loaded onto it.

  `Ash.load!/2` is the obvious tool, it mutates nothing, and plenty of real applications
  permit exactly this. This example forbids it, deliberately. See the README section "Why
  `Ash.load/2` gets no exception". The short version: a need for `Ash.load/2` in the web layer
  means the read action returned an incomplete struct. The fix belongs in the domain. Use a
  `prepare build(load: [...])` on the action, as `Example.Post`'s `:list_published` action
  does for `:excerpt` and `:word_count`, or write a purpose-built action. A narrow exception is
  also impossible here. `boundary`'s external-dependency check works at application
  granularity, so permitting `Ash.load/2` also permits `Ash.read!/1`, `Ash.destroy!/1`, and the
  rest of `:ash`.

  Not compiled by any normal build; see `mix.exs` and
  `test/example_web/ash_violation_test.exs`.
  """

  use ExampleWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    posts =
      Example.list_published_posts!()
      # Violation: the struct arrived already loaded, and even if it had not, this is the
      # domain's job.
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
