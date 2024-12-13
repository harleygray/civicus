defmodule Civicus.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CivicusWeb.Telemetry,
      Civicus.Repo,
      {DNSCluster, query: Application.get_env(:civicus, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:civicus, Oban)},
      {Phoenix.PubSub, name: Civicus.PubSub},
      {Finch, name: Civicus.Finch},
      CivicusWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Civicus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CivicusWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
