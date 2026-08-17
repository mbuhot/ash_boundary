defmodule Example.Application do
  @moduledoc """
  The OTP application callback module, and a boundary of its own.

  `start/2` below names modules from every corner of the app, such as `ExampleWeb.Telemetry` and
  `ExampleWeb.Endpoint`. It therefore needs `deps` that no other boundary should have. Its own
  boundary declares those deps once, here. Without it, the deps must go into `Example`'s or
  `ExampleWeb`'s list, where they would widen what the rest of the app can reference.
  `Boundary`'s own moduledoc recommends this arrangement for this module.

  `top_level?: true` promotes this module out of the `Example` boundary, which would otherwise
  claim it by name nesting. `Example` is the Ash domain in this example, and this module must not
  live inside it. A supervision tree that starts the endpoint is not part of the domain, and the
  domain must not gain a dep on `ExampleWeb` to accommodate it. The promotion makes this module a
  sibling of `Example` and `ExampleWeb`, which is what lets it declare deps on both.
  """

  use Application

  use Boundary, top_level?: true, deps: [Example, ExampleWeb]

  @impl true
  def start(_type, _args) do
    children = [
      ExampleWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:example, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Example.PubSub},
      # Start a worker by calling: Example.Worker.start_link(arg)
      # {Example.Worker, arg},
      # Start to serve requests, typically the last entry
      ExampleWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Example.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      maybe_seed_posts()
      {:ok, pid}
    end
  end

  # `Ash.DataLayer.Ets` stores records in the running node's ETS tables, so `mix phx.server`
  # starts with an empty blog. Seeding here (enabled by `config :example, seed_posts?: true`
  # in `config/dev.exs` only) means http://localhost:4000 shows real records rather than an
  # empty list. Note this goes through `Example`'s exported code interface, like every
  # other caller in this example.
  defp maybe_seed_posts do
    if Application.get_env(:example, :seed_posts?, false) do
      Example.create_post!(%{
        title: "Boundaries for Ash domains",
        author: "mbuhot",
        body: "AshBoundary computes a boundary declaration from a domain's resources block."
      })

      Example.create_post!(%{
        title: "A web layer with no Ash surface",
        author: "mbuhot",
        body: "The LiveView reads structs and calls domain functions, and cannot call Ash itself."
      })
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
