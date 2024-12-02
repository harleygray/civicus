defmodule CivicusWeb.Components.InquiryStatus do
  use Phoenix.LiveComponent
  alias Civicus.Repo
  import Ecto.Query

  def render(assigns) do
    ~H"""
    <div class="bg-white p-4 rounded-lg shadow">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-semibold">Processing Status</h3>
        <span class={"px-2 py-1 rounded-full text-sm #{status_color(@inquiry.status)}"}>
          <%= String.capitalize(@inquiry.status) %>
        </span>
      </div>

      <%= if active_job?(@inquiry.id) do %>
        <div class="text-sm text-gray-600">
          <p class="mb-2">Transcription in progress...</p>
          <%= if @messages && length(@messages) > 0 do %>
            <div class="bg-gray-50 p-2 rounded">
              <p class="font-medium">Latest updates:</p>
              <%= for message <- Enum.take(@messages, 3) do %>
                <p class="text-xs mt-1"><%= message %></p>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(socket) do
    {:ok, assign(socket, messages: [])}
  end

  def update(%{inquiry: inquiry} = assigns, socket) do
    if socket.assigns[:inquiry_id] != inquiry.id do
      topic = "transcription_progress:#{inquiry.id}"
      if socket.assigns[:inquiry_id], do: Phoenix.PubSub.unsubscribe(Civicus.PubSub, topic)
      Phoenix.PubSub.subscribe(Civicus.PubSub, topic)
    end

    {:ok, assign(socket, assigns)}
  end

  def handle_info({:transcription_progress, message}, socket) do
    messages = [message | socket.assigns.messages] |> Enum.take(5)
    {:noreply, assign(socket, messages: messages)}
  end

  defp active_job?(inquiry_id) do
    Oban.Job
    |> where([j], j.worker == "Civicus.Workers.YoutubeProcessor")
    |> where([j], fragment("(?)->>'inquiry_id' = ?", j.args, ^to_string(inquiry_id)))
    |> where([j], j.state in ["available", "scheduled", "executing", "retryable"])
    |> Repo.exists?()
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
