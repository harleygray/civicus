defmodule CivicusWeb.Components.TranscriptView do
  use CivicusWeb, :live_component
  require Logger

  @impl true
  def update(%{inquiry: inquiry} = assigns, socket) do
    if !Map.get(socket.assigns, :subscribed?) && connected?(socket) do
      Phoenix.PubSub.subscribe(Civicus.PubSub, "speaker_mappings:#{inquiry.id}")
    end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(subscribed?: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="transcript-container">
      <div class="transcript-content">
        <%= if @inquiry.structured_transcript do %>
          <div class="transcript-utterances">
            <%= for utterance <- @inquiry.structured_transcript["utterances"] || [] do %>
              <div class="transcript-utterance">
                <div class="transcript-header">
                  <span class="transcript-speaker">
                    <%= get_speaker_name(utterance["speaker"], @inquiry.speaker_mappings) %>
                  </span>
                  <button
                    class="transcript-timestamp"
                    phx-click="seek_video"
                    phx-target={@myself}
                    phx-value-time={trunc(utterance["start"] / 1000)}
                  >
                    <%= format_timestamp(utterance["start"]) %>
                  </button>
                </div>
                <p class="transcript-text"><%= utterance["text"] %></p>
              </div>
            <% end %>
          </div>
        <% else %>
          <p class="transcript-empty">No structured transcript available yet.</p>
        <% end %>

        <%= if @transcribing? do %>
          <div class="transcript-progress">
            <p class="transcript-progress-text">
              <%= if @progress do %>
                <%= @progress %>
              <% else %>
                Transcription in progress...
              <% end %>
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp get_speaker_name(speaker_id, speaker_mappings) when is_map(speaker_mappings) do
    case Map.get(speaker_mappings || %{}, speaker_id) do
      nil -> speaker_id
      name -> name
    end
  end

  defp get_speaker_name(speaker_id, _), do: speaker_id

  # Format timestamp for display
  defp format_timestamp(nil), do: "00:00"

  defp format_timestamp(timestamp) when is_integer(timestamp) do
    # Convert milliseconds to seconds first
    total_seconds = div(timestamp, 1000)
    minutes = div(total_seconds, 60)
    seconds = rem(total_seconds, 60)
    "#{String.pad_leading("#{minutes}", 2, "0")}:#{String.pad_leading("#{seconds}", 2, "0")}"
  end

  defp format_timestamp(timestamp) when is_float(timestamp) do
    format_timestamp(trunc(timestamp))
  end

  defp format_timestamp(timestamp) when is_binary(timestamp) do
    case Integer.parse(timestamp) do
      {ms, _} -> format_timestamp(ms)
      :error -> "00:00"
    end
  end

  def handle_event("seek_video", %{"time" => time}, socket) do
    {time_int, _} = Integer.parse(time)
    {:noreply, push_event(socket, "seek_video", %{time: time_int})}
  end

  @impl true
  def handle_info({:speaker_mappings_updated, speaker_mappings}, socket) do
    Logger.debug("TranscriptView received speaker_mappings_updated")

    {:noreply,
     assign(socket, inquiry: %{socket.assigns.inquiry | speaker_mappings: speaker_mappings})}
  end
end
