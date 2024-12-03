defmodule CivicusWeb.Components.VideoPlayer do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="video-container">
      <div class="aspect-w-16 aspect-h-9 mb-4">
        <div
          id="youtube-player"
          phx-hook="YouTubePlayer"
          data-embed-url={@inquiry.youtube_embed}
          class="w-full h-full"
        >
        </div>
      </div>

      <div class="text-sm text-gray-600 mt-2">
        <p class="font-medium"><%= @inquiry.name %></p>
        <%= if @inquiry.date_held do %>
          <p>Date: <%= Calendar.strftime(@inquiry.date_held, "%d %B %Y") %></p>
        <% end %>
      </div>
    </div>
    """
  end

  def mount(socket) do
    {:ok, socket}
  end
end
