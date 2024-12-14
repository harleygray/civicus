defmodule CivicusWeb.Components.TimelineViewer do
  use CivicusWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="timeline-container h-full w-full relative">
      <div class="absolute inset-0 overflow-y-auto" style="direction: rtl;">
        <div class="h-full pl-3" style="direction: ltr;">
          <div class="flex flex-col h-full bg-gray-100 rounded-full p-1 w-2">
            <%= for {segment, index} <- Enum.with_index(timeline_segments(@inquiry.structured_transcript["utterances"], @inquiry.speaker_mappings)) do %>
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
      </div>
    </div>
    """
  end

  def mount(socket) do
    {:ok, socket}
  end

  defp timeline_segments(utterances, _speaker_mappings) do
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

  defp calculate_total_duration(utterances) do
    last_utterance = List.last(utterances)
    # Add 10 seconds for the last segment
    last_utterance["start"] + 10_000
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
