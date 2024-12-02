defmodule CivicusWeb.Components.TranscriptionProgress do
  use Phoenix.LiveComponent
  require Logger

  def render(assigns) do
    ~H"""
    <div class="fixed bottom-4 right-4 max-w-sm w-full bg-white shadow-lg rounded-lg p-4">
      <div class="flex items-center justify-between mb-2">
        <h3 class="text-lg font-semibold">Transcription Progress</h3>
        <button
          phx-click="close_progress"
          phx-target={@myself}
          class="text-gray-500 hover:text-gray-700"
        >
          ×
        </button>
      </div>
      <div class="space-y-2">
        <%= for message <- Enum.reverse(@messages) do %>
          <p class="text-sm text-gray-600"><%= message %></p>
        <% end %>
      </div>
    </div>
    """
  end

  def mount(socket) do
    Logger.info("TranscriptionProgress component mounted")
    {:ok, assign(socket, messages: [])}
  end

  def update(%{inquiry_id: inquiry_id} = assigns, socket) do
    Logger.info("TranscriptionProgress update called for inquiry #{inquiry_id}")

    if socket.assigns[:inquiry_id] != inquiry_id do
      if socket.assigns[:inquiry_id] do
        Logger.info(
          "Unsubscribing from previous topic: transcription_progress:#{socket.assigns.inquiry_id}"
        )

        Phoenix.PubSub.unsubscribe(
          Civicus.PubSub,
          "transcription_progress:#{socket.assigns.inquiry_id}"
        )
      end

      Logger.info("Subscribing to new topic: transcription_progress:#{inquiry_id}")
      Phoenix.PubSub.subscribe(Civicus.PubSub, "transcription_progress:#{inquiry_id}")
    end

    {:ok, assign(socket, assigns)}
  end

  def handle_info({:transcription_progress, message}, socket) do
    Logger.info("Received progress message: #{message}")
    messages = [message | socket.assigns.messages] |> Enum.take(10)
    {:noreply, assign(socket, messages: messages)}
  end

  def handle_event("close_progress", _, socket) do
    send(self(), :hide_progress)
    {:noreply, socket}
  end
end
