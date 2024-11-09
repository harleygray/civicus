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
      {Phoenix.PubSub, name: Civicus.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Civicus.Finch},
      # Start a worker by calling: Civicus.Worker.start_link(arg)
      # {Civicus.Worker, arg},
      # Start to serve requests, typically the last entry
      CivicusWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
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
