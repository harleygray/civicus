defmodule CivicusWeb.Components.VideoPlayer do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div class="video-container">
      <div class="mb-4">
        <h3 class="text-lg font-semibold mb-2"><%= @inquiry.name %></h3>
        <div class="text-sm text-gray-600 mb-4">
          <p>Committee: <%= @inquiry.committee %></p>
          <p>Date: <%= Calendar.strftime(@inquiry.date_held, "%d %B %Y") %></p>
          <p>Status: <%= @inquiry.status %></p>
        </div>

        <form phx-submit="update_time" phx-target={@myself}>
          <label class="block text-sm font-medium text-gray-700">Jump to time (seconds)</label>
          <div class="flex items-center">
            <input type="number" name="time" class="time-input" value={@current_time} />
            <button type="submit" class="jump-button">Jump</button>
          </div>
        </form>

        <%= if @inquiry.status == "pending" do %>
          <button
            phx-click="start_transcription"
            phx-target={@myself}
            class="mt-4 bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
          >
            Start Transcription
          </button>
        <% end %>
      </div>

      <div class="aspect-w-16 aspect-h-9">
        <iframe
          src={"#{@inquiry.youtube_embed}?start=#{@current_time}&t=#{@current_time}&reload=#{@timestamp}"}
          title="YouTube video player"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
          allowfullscreen
          class="w-full h-full"
        >
        </iframe>
      </div>

      <%= if @inquiry.transcript do %>
        <div class="mt-4 p-4 bg-gray-50 rounded">
          <h4 class="font-semibold mb-2">Transcript</h4>
          <div class="whitespace-pre-wrap"><%= @inquiry.transcript %></div>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(socket) do
    {:ok,
     assign(socket,
       current_time: 0,
       timestamp: :os.system_time(:millisecond)
     )}
  end

  def handle_event("update_time", %{"time" => time}, socket) when time != "" do
    {time_int, _} = Integer.parse(time)
    new_time = max(0, time_int)
    timestamp = :os.system_time(:millisecond)

    {:noreply,
     assign(socket,
       current_time: new_time,
       timestamp: timestamp
     )}
  end

  def handle_event("update_time", _, socket) do
    {:noreply, socket}
  end

  def handle_event("start_transcription", _, socket) do
    Civicus.Inquiries.start_transcription(socket.assigns.inquiry)
    # Here you would trigger your GROQ transcription job
    # You might want to use a background job system like Oban for this
    {:noreply, socket}
  end
end
