defmodule CivicusWeb.LandingLive.Index do
  use CivicusWeb, :live_view
  require Logger
  alias CivicusWeb.Components.HeaderNav, as: HeaderNav

  @impl true
  def mount(_params, _session, socket) do
    Logger.debug("Mounting LandingLive.Index")
    {:ok, socket}
  end
end
