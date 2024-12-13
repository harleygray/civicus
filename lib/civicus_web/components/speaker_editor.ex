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

    {:ok, assign(socket, new_speaker: "", member_suggestions: [])}
  end

  @impl true
  def update(%{inquiry: inquiry} = assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mt-8 border-t border-gray-200 pt-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">Speaker Management</h3>

      <div class="space-y-4">
        <.form
          for={%{}}
          phx-submit="add_speaker"
          phx-target={@myself}
          class="flex items-center space-x-2"
        >
          <div class="flex-none w-20">
            <.input
              type="text"
              name="next_speaker_id"
              value={String.replace(next_speaker_id(@inquiry), "Speaker ", "")}
              disabled
              class="text-center font-medium bg-gray-50"
            />
          </div>
          <div class="flex-1 relative">
            <.input
              type="text"
              name="new_speaker"
              value={@new_speaker}
              placeholder="Add speaker name..."
              phx-change="update_new_speaker"
              phx-target={@myself}
              autocomplete="off"
              list="member-suggestions"
            />
            <%= if length(@member_suggestions) > 0 do %>
              <div class="absolute z-10 w-full bg-white mt-1 rounded-md shadow-lg border border-gray-200">
                <%= for member <- @member_suggestions do %>
                  <div
                    class="px-4 py-2 hover:bg-gray-100 cursor-pointer"
                    phx-click="select_member"
                    phx-target={@myself}
                    phx-value-name={member_display_name(member)}
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
          <.button type="submit" class="button-gradient">
            Add
          </.button>
        </.form>

        <div class="speaker-list max-h-96 overflow-y-auto divide-y divide-gray-200">
          <%= for {speaker_id, name} <- Enum.sort_by(@inquiry.speaker_mappings || %{}, fn {id, _} ->
            id
            |> String.replace("Speaker ", "")
            |> String.to_integer()
          end) do %>
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
              <div class="flex-1">
                <.input
                  type="text"
                  name={"speaker_name_#{speaker_id}"}
                  value={name}
                  phx-blur="update_speaker"
                  phx-target={@myself}
                  phx-value-speaker-id={speaker_id}
                />
              </div>
              <button
                type="button"
                phx-click="remove_speaker"
                phx-target={@myself}
                phx-value-speaker-id={speaker_id}
                class="flex-none text-red-600 hover:text-red-800"
              >
                <.icon name="hero-trash" class="h-5 w-5" />
              </button>
            </div>
          <% end %>
        </div>

        <%= if map_size(@inquiry.speaker_mappings || %{}) == 0 do %>
          <div class="text-center text-gray-500 py-4">
            No speakers added yet
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Get next available speaker ID (A, B, C, etc.)
  defp next_speaker_id(inquiry) do
    existing_ids = Map.keys(inquiry.speaker_mappings || %{})

    next_number =
      existing_ids
      |> Enum.map(&String.replace(&1, "Speaker ", ""))
      |> Enum.map(&String.to_integer/1)
      |> Enum.max(fn -> -1 end)
      |> Kernel.+(1)

    "Speaker #{next_number}"
  end

  @impl true
  def handle_event("add_speaker", %{"new_speaker" => name}, socket) when is_binary(name) do
    if String.trim(name) == "" do
      {:noreply, socket}
    else
      handle_add_speaker(name, socket)
    end
  end

  def handle_event("add_speaker", _params, socket), do: {:noreply, socket}

  def handle_event("update_speaker", %{"value" => name, "speaker-id" => speaker_id}, socket) do
    speaker_mappings = Map.put(socket.assigns.inquiry.speaker_mappings || %{}, speaker_id, name)
    update_speaker_mappings(socket, speaker_mappings)
  end

  def handle_event("update_speaker_id", %{"value" => new_id, "old-id" => old_id}, socket) do
    old_mappings = socket.assigns.inquiry.speaker_mappings || %{}

    if new_id != old_id and Map.has_key?(old_mappings, new_id) do
      {:noreply, put_flash(socket, :error, "Speaker ID already exists")}
    else
      {value, mappings} = Map.pop(old_mappings, old_id)
      new_mappings = Map.put(mappings, new_id, value)
      update_speaker_mappings(socket, new_mappings)
    end
  end

  def handle_event("remove_speaker", %{"speaker-id" => speaker_id}, socket) do
    speaker_mappings = Map.delete(socket.assigns.inquiry.speaker_mappings || %{}, speaker_id)
    update_speaker_mappings(socket, speaker_mappings)
  end

  defp handle_add_speaker("", socket), do: {:noreply, socket}

  defp handle_add_speaker(name, socket) do
    next_id = next_speaker_id(socket.assigns.inquiry)

    # Get current speaker mappings or initialize empty map
    current_mappings = socket.assigns.inquiry.speaker_mappings || %{}

    # Add new speaker mapping
    speaker_mappings = Map.put(current_mappings, next_id, name)

    case Inquiries.update_speaker_mappings(socket.assigns.inquiry, speaker_mappings) do
      {:ok, %{inquiry: updated_inquiry}} ->
        # Broadcast the change to all subscribers
        Phoenix.PubSub.broadcast(
          Civicus.PubSub,
          "speaker_mappings:#{updated_inquiry.id}",
          {:speaker_mappings_updated, speaker_mappings}
        )

        {:noreply,
         socket
         |> assign(inquiry: updated_inquiry)
         |> assign(new_speaker: "")
         |> put_flash(:info, "Speaker added successfully")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to add speaker")
         |> assign(new_speaker: "")}
    end
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

  def handle_event("update_new_speaker", %{"new_speaker" => value} = _params, socket) do
    suggestions =
      if String.length(value) >= 2 do
        Members.search_by_name(value)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:new_speaker, value)
     |> assign(:member_suggestions, suggestions)}
  end

  def handle_event("update_new_speaker", _params, socket), do: {:noreply, socket}

  def handle_event("select_member", %{"name" => name}, socket) do
    {:noreply,
     socket
     |> assign(:new_speaker, name)
     |> assign(:member_suggestions, [])}
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
