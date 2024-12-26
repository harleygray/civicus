defmodule CivicusWeb.Components.SpeakerEditor do
  use CivicusWeb, :live_component
  alias Civicus.Inquiries
  alias Civicus.Inquiries.SpeakerMapping
  alias Civicus.Parliament.Members

  @impl true
  def mount(socket) do
    if socket.assigns[:inquiry] && connected?(socket) do
      Phoenix.PubSub.subscribe(Civicus.PubSub, "speaker_mappings:#{socket.assigns.inquiry.id}")
    end

    {:ok, assign(socket, member_suggestions: %{}, editing_speaker: nil)}
  end

  @impl true
  def update(%{inquiry: inquiry} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(transcript_speakers: get_transcript_speakers(inquiry))}
  end

  defp get_transcript_speakers(inquiry) do
    case inquiry.structured_transcript do
      %{"utterances" => utterances} when is_list(utterances) ->
        utterances
        |> Enum.map(& &1["speaker"])
        |> Enum.uniq()
        |> Enum.sort_by(fn speaker_id ->
          speaker_id
          |> String.replace("Speaker ", "")
          |> String.to_integer()
        end)

      _ ->
        []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mt-8 border-t border-gray-200 pt-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">Speaker Management</h3>

      <div class="speaker-list max-h-96 overflow-y-auto divide-y divide-gray-200">
        <%= for speaker_id <- @transcript_speakers do %>
          <div class="flex items-center space-x-2 py-2">
            <div class="flex-none w-20">
              <.input
                type="text"
                name={"speaker_id_#{speaker_id}"}
                value={String.replace(speaker_id, "Speaker ", "")}
                disabled
                class="text-center font-medium bg-gray-50"
              />
            </div>
            <div class="flex-1 relative">
              <form phx-change="search_member" phx-submit="update_speaker" phx-target={@myself}>
                <input
                  type="text"
                  name="value"
                  value={Map.get(@inquiry.speaker_mappings || %{}, speaker_id, "")}
                  placeholder="Enter speaker name..."
                  phx-focus="start_editing"
                  phx-target={@myself}
                  phx-value-speaker-id={speaker_id}
                  autocomplete="off"
                  class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                />
                <input type="hidden" name="speaker-id" value={speaker_id} />
              </form>
              <%= if @editing_speaker == speaker_id && length(Map.get(@member_suggestions, speaker_id, [])) > 0 do %>
                <div class="absolute z-10 w-full bg-white mt-1 rounded-md shadow-lg border border-gray-200">
                  <%= for member <- Map.get(@member_suggestions, speaker_id, []) do %>
                    <div
                      class="px-4 py-2 hover:bg-gray-100 cursor-pointer"
                      phx-click="select_member"
                      phx-target={@myself}
                      phx-value-name={member_display_name(member)}
                      phx-value-speaker-id={speaker_id}
                    >
                      <%= member_display_name(member) %>
                      <span class="text-sm text-gray-500">
                        (<%= member.chamber %>)
                      </span>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
            <div class="flex-none space-x-2">
              <%= if Map.get(@inquiry.speaker_mappings || %{}, speaker_id) do %>
                <button
                  type="button"
                  phx-click="clear_speaker"
                  phx-target={@myself}
                  phx-value-speaker-id={speaker_id}
                  class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-gray-700 bg-gray-100 hover:bg-gray-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500"
                >
                  Clear
                </button>
              <% end %>
            </div>
          </div>
        <% end %>

        <%= if length(@transcript_speakers) == 0 do %>
          <div class="text-center text-gray-500 py-4">
            No speakers found in transcript
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event("start_editing", %{"speaker-id" => speaker_id}, socket) do
    {:noreply, assign(socket, editing_speaker: speaker_id)}
  end

  def handle_event("search_member", %{"value" => value, "speaker-id" => speaker_id}, socket) do
    suggestions =
      if String.length(value) >= 2 do
        Members.search_by_name(value)
      else
        []
      end

    {:noreply,
     socket
     |> assign(
       :member_suggestions,
       Map.put(socket.assigns.member_suggestions, speaker_id, suggestions)
     )}
  end

  def handle_event("select_member", %{"name" => name, "speaker-id" => speaker_id}, socket) do
    speaker_mappings = Map.put(socket.assigns.inquiry.speaker_mappings || %{}, speaker_id, name)

    socket =
      socket
      |> update(:member_suggestions, &Map.delete(&1, speaker_id))
      |> assign(editing_speaker: nil)

    update_speaker_mappings(socket, speaker_mappings)
  end

  def handle_event("update_speaker", %{"value" => name, "speaker-id" => speaker_id}, socket) do
    if String.trim(name) == "" do
      speaker_mappings = Map.delete(socket.assigns.inquiry.speaker_mappings || %{}, speaker_id)
      update_speaker_mappings(socket, speaker_mappings)
    else
      speaker_mappings = Map.put(socket.assigns.inquiry.speaker_mappings || %{}, speaker_id, name)
      socket = socket |> assign(:editing_speaker, nil)
      update_speaker_mappings(socket, speaker_mappings)
    end
  end

  def handle_event("clear_speaker", %{"speaker-id" => speaker_id}, socket) do
    speaker_mappings = Map.delete(socket.assigns.inquiry.speaker_mappings || %{}, speaker_id)

    socket = socket |> assign(:editing_speaker, nil)
    update_speaker_mappings(socket, speaker_mappings)
  end

  defp update_speaker_mappings(socket, speaker_mappings) do
    case Inquiries.update_speaker_mappings(socket.assigns.inquiry, speaker_mappings) do
      {:ok, %{inquiry: inquiry}} ->
        Phoenix.PubSub.broadcast(
          Civicus.PubSub,
          "speaker_mappings:#{inquiry.id}",
          {:speaker_mappings_updated, speaker_mappings}
        )

        {:noreply,
         socket
         |> assign(inquiry: inquiry)
         |> put_flash(:info, "Speakers updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update speakers")}
    end
  end

  # Handle broadcast messages
  def handle_info({:speaker_mappings_updated, speaker_mappings}, socket) do
    {:noreply,
     assign(socket, inquiry: %{socket.assigns.inquiry | speaker_mappings: speaker_mappings})}
  end

  defp member_display_name(member) do
    base_name =
      [member.first_name, member.surname]
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(" ")

    case member.chamber do
      "Senate" -> "Sen #{base_name}"
      "House of Representatives" -> "#{base_name} MP"
      _ -> base_name
    end
  end
end
