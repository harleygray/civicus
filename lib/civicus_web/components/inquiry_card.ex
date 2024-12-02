defmodule CivicusWeb.Components.InquiryCard do
  use CivicusWeb, :live_component

  def render(assigns) do
    ~H"""
    <div
      class="bg-white rounded-lg shadow-md hover:shadow-lg transition-all duration-200 border border-gray-200 cursor-pointer"
      phx-click={JS.navigate(~p"/inquiry_interface/#{@inquiry.slug || @inquiry.id}")}
    >
      <div class="relative aspect-video">
        <iframe
          src={@inquiry.youtube_embed}
          title={@inquiry.name}
          class="absolute inset-0 w-full h-full pointer-events-none"
          frameborder="0"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
          allowfullscreen
        >
        </iframe>
      </div>

      <div class="p-4">
        <div class="flex justify-between items-start mb-4">
          <h2 class="text-xl font-semibold text-gray-900">
            <%= @inquiry.name %>
          </h2>
        </div>

        <div class="space-y-3 text-sm text-gray-600">
          <%= if @inquiry.committee && @inquiry.committee != "n/a" do %>
            <div class="flex justify-between items-center">
              <span class="font-medium">Committee:</span>
              <span class="text-gray-900"><%= @inquiry.committee %></span>
            </div>
          <% end %>
          <%= if @inquiry.date_held do %>
            <div class="flex justify-between items-center">
              <span class="font-medium">Date held:</span>
              <span class="text-gray-900">
                <%= Calendar.strftime(@inquiry.date_held, "%B %d, %Y") %>
              </span>
            </div>
          <% end %>
          <div class="flex justify-between items-center">
            <span class="font-medium">Status:</span>
            <span class={[
              "px-2 py-1 rounded-full text-xs font-medium",
              status_color(@inquiry.status)
            ]}>
              <%= String.replace(@inquiry.status, "_", " ") |> String.capitalize() %>
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp status_color(status) do
    case status do
      "pending" -> "bg-gray-100 text-gray-800"
      "work_in_progress" -> "bg-blue-100 text-blue-800"
      "published" -> "bg-green-100 text-green-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end
end
