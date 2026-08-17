defmodule Example.Application do
  @moduledoc false

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
