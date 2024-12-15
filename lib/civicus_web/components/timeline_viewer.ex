defmodule CivicusWeb.Components.TimelineViewer do
  use CivicusWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="timeline-viewer">
      <%= if has_transcript?(@inquiry) do %>
        <div class="h-full flex flex-col">
          <div class="flex-1 overflow-y-auto">
            <%= for {segment, index} <- Enum.with_index(timeline_segments(@inquiry.structured_transcript["utterances"], @current_time)) do %>
              <div
                class="timeline-segment group"
                style={"height: #{segment.height_percentage}px; min-height: 10px;"}
                phx-click="seek_video"
                phx-value-time={trunc(segment.start)}
                phx-target={@myself}
              >
                <div class="h-full w-5 bg-gray-300 hover:bg-blue-500 rounded-full cursor-pointer transition-colors duration-200">
                </div>

                <div class={[
                  "timeline-tooltip",
                  cond do
                    index < 5 -> "top-0 translate-y-[10%]"
                    index < 10 -> "top-0 translate-y-[25%]"
                    true -> "top-1/2 -translate-y-1/2"
                  end
                ]}>
                  <div class="text-sm font-semibold text-gray-900">
                    <%= get_mapped_speaker_name(segment.speaker, @inquiry.speaker_mappings) %>
                  </div>
                  <div class="mt-1 text-sm text-gray-600 line-clamp-3">
                    <%= segment.text %>
                  </div>
                  <div class="mt-1 text-xs text-gray-400">
                    <%= format_timestamp(segment.start) %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% else %>
        <div class="h-full flex items-center justify-center text-gray-500">
          <p>No transcript available</p>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(socket) do
    {:ok, assign(socket, current_time: 0)}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(:inquiry, assigns.inquiry)
     |> assign(:current_time, assigns[:current_time] || 0)}
  end

  defp has_transcript?(inquiry) do
    case inquiry do
      %{structured_transcript: %{"utterances" => utterances}}
      when is_list(utterances) and utterances != [] ->
        true

      _ ->
        false
    end
  end

  defp timeline_segments(nil, _current_time), do: []
  defp timeline_segments([], _current_time), do: []

  defp timeline_segments(utterances, _current_time) do
    total_duration = calculate_total_duration(utterances)

    utterances
    |> Enum.chunk_every(2, 1, [nil])
    |> Enum.map(fn [current, next] ->
      end_time = if next, do: next["start"], else: current["start"] + 10_000
      duration = end_time - current["start"]
      height = max(20, duration / total_duration * 14000)

      %{
        speaker: current["speaker"],
        text: current["text"],
        start: current["start"],
        end: end_time,
        height_percentage: height
      }
    end)
  end

  defp calculate_total_duration(nil), do: 0
  defp calculate_total_duration([]), do: 0

  defp calculate_total_duration(utterances) do
    utterances
    |> List.last()
    |> Map.get("start", 0)
  end

  defp format_timestamp(milliseconds) do
    seconds = div(trunc(milliseconds), 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    "#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(remaining_seconds), 2, "0")}"
  end

  def handle_event("seek_video", %{"time" => time}, socket) do
    send(self(), {:seek_video, time})
    {:noreply, socket}
  end

  defp get_mapped_speaker_name(speaker_id, speaker_mappings) when is_map(speaker_mappings) do
    case Map.get(speaker_mappings || %{}, speaker_id) do
      nil -> speaker_id
      name -> name
    end
  end

  defp get_mapped_speaker_name(speaker_id, _), do: speaker_id
end
