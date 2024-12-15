defmodule CivicusWeb.Components.ChapterEditor do
  use CivicusWeb, :live_component

  @chapter_types ["opening", "testimony", "questioning", "closing", "other"]

  def render(assigns) do
    ~H"""
    <div class="bg-white h-full flex flex-col">
      <div class="border-b p-4 flex items-center justify-between">
        <div class="flex items-center space-x-2">
          <div class="w-4 h-4 bg-gray-200 rounded-full"></div>
          <span class="text-sm font-medium">Unreviewed</span>
        </div>
        <button
          phx-click="add_chapter"
          phx-target={@myself}
          class="px-3 py-1.5 bg-blue-500 text-white text-sm rounded hover:bg-blue-600"
        >
          Add Chapter
        </button>
      </div>

      <div class="flex-1 overflow-y-auto p-4">
        <%= for {chapter_id, chapter} <- @chapters || %{} do %>
          <div class="mb-6 border rounded-lg shadow-sm">
            <div class="p-4">
              <div class="space-y-4">
                <div class="flex items-center justify-between">
                  <div class="flex items-center space-x-2">
                    <input
                      type="checkbox"
                      checked={chapter["reviewed"]}
                      phx-click="toggle_reviewed"
                      phx-target={@myself}
                      phx-value-chapter-id={chapter_id}
                      class="rounded border-gray-300 text-blue-500 focus:ring-blue-500"
                    />
                    <span class="text-sm text-gray-600">Reviewed?</span>
                  </div>
                  <div class="flex items-center space-x-2">
                    <button
                      phx-click="save_chapter"
                      phx-target={@myself}
                      phx-value-chapter-id={chapter_id}
                      class="text-sm text-green-500 hover:text-green-600"
                    >
                      Save
                    </button>
                    <button
                      phx-click="delete_chapter"
                      phx-target={@myself}
                      phx-value-chapter-id={chapter_id}
                      class="text-gray-400 hover:text-red-500"
                    >
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M6 18L18 6M6 6l12 12"
                        />
                      </svg>
                    </button>
                  </div>
                </div>

                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Chapter Type</label>
                  <div id={"chapter-type-wrapper-#{chapter_id}"} phx-update="ignore">
                    <select
                      id={"chapter-type-#{chapter_id}"}
                      name="chapter_type"
                      phx-hook="ChapterType"
                      data-chapter-id={chapter_id}
                      data-phx-target={@myself.cid}
                      class="w-full text-sm border-gray-300 rounded-md focus:border-blue-500 focus:ring-blue-500"
                    >
                      <%= for type <- @chapter_types do %>
                        <option value={type} selected={type == chapter["type"]}>
                          <%= String.capitalize(type) %>
                        </option>
                      <% end %>
                    </select>
                  </div>
                </div>

                <div>
                  <input
                    type="text"
                    value={chapter["title"]}
                    placeholder="Title"
                    phx-blur="update_chapter"
                    phx-target={@myself}
                    phx-value-field="title"
                    phx-value-chapter-id={chapter_id}
                    class="w-full text-lg font-medium border-gray-300 rounded-md focus:border-blue-500 focus:ring-blue-500"
                  />
                </div>

                <div class="flex space-x-4">
                  <div class="flex-1">
                    <label class="block text-xs text-gray-500 mb-1">Start</label>
                    <div class="flex items-center space-x-2">
                      <input
                        type="text"
                        value={format_timestamp(chapter["start_time"])}
                        phx-blur="update_timestamp"
                        phx-target={@myself}
                        phx-value-field="start_time"
                        phx-value-chapter-id={chapter_id}
                        class="flex-1 text-sm border-gray-300 rounded-md"
                        placeholder="MM:SS"
                      />
                      <button
                        phx-click="set_time"
                        phx-target={@myself}
                        phx-value-field="start_time"
                        phx-value-chapter-id={chapter_id}
                        class="text-sm text-blue-500 hover:text-blue-600"
                      >
                        Set
                      </button>
                    </div>
                  </div>

                  <div class="flex-1">
                    <label class="block text-xs text-gray-500 mb-1">End</label>
                    <div class="flex items-center space-x-2">
                      <input
                        type="text"
                        value={format_timestamp(chapter["end_time"])}
                        phx-blur="update_timestamp"
                        phx-target={@myself}
                        phx-value-field="end_time"
                        phx-value-chapter-id={chapter_id}
                        class="flex-1 text-sm border-gray-300 rounded-md"
                        placeholder="MM:SS"
                      />
                      <button
                        phx-click="set_time"
                        phx-target={@myself}
                        phx-value-field="end_time"
                        phx-value-chapter-id={chapter_id}
                        class="text-sm text-blue-500 hover:text-blue-600"
                      >
                        Set
                      </button>
                    </div>
                  </div>
                </div>

                <div>
                  <textarea
                    phx-blur="update_chapter"
                    phx-target={@myself}
                    phx-value-field="summary"
                    phx-value-chapter-id={chapter_id}
                    class="w-full text-sm border-gray-300 rounded-md focus:border-blue-500 focus:ring-blue-500"
                    rows="3"
                    placeholder="Summary"
                  ><%= chapter["summary"] %></textarea>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def mount(socket) do
    {:ok, assign(socket, chapter_types: @chapter_types)}
  end

  def update(%{inquiry: inquiry} = assigns, socket) do
    chapters = Map.get(inquiry, :chapters, %{})
    IO.inspect(chapters, label: "Current Chapters")

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:chapters, chapters)}
  end

  def handle_event("add_chapter", _params, socket) do
    chapter_id = generate_chapter_id()

    new_chapter = %{
      "title" => "New Chapter",
      "type" => "other",
      "summary" => "",
      "start_time" => 0,
      "end_time" => 0,
      "reviewed" => false
    }

    updated_chapters = Map.put(socket.assigns.chapters || %{}, chapter_id, new_chapter)

    case Civicus.Inquiries.update_inquiry(socket.assigns.inquiry, %{chapters: updated_chapters}) do
      {:ok, updated_inquiry} ->
        {:noreply,
         socket
         |> assign(:inquiry, updated_inquiry)
         |> assign(:chapters, updated_chapters)
         |> put_flash(:info, "Chapter added successfully")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error adding chapter")}
    end
  end

  def handle_event("save_chapter", %{"chapter-id" => chapter_id}, socket) do
    chapter = get_in(socket.assigns.chapters, [chapter_id])

    if chapter do
      current_chapters = socket.assigns.chapters

      case Civicus.Inquiries.update_inquiry(socket.assigns.inquiry, %{chapters: current_chapters}) do
        {:ok, updated_inquiry} ->
          {:noreply,
           socket
           |> assign(:inquiry, updated_inquiry)
           |> assign(:chapters, current_chapters)
           |> put_flash(:info, "Chapter saved successfully")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Error saving chapter")}
      end
    else
      {:noreply, socket |> put_flash(:error, "Chapter not found")}
    end
  end

  def handle_event(
        "update_chapter",
        %{"chapter-id" => chapter_id, "field" => field, "value" => value} = params,
        socket
      ) do
    IO.inspect(params, label: "Update Chapter Params")

    updated_chapters =
      Map.update!(socket.assigns.chapters, chapter_id, fn chapter ->
        Map.put(chapter, field, value)
      end)

    # Immediately save changes for type updates
    if field == "type" do
      case Civicus.Inquiries.update_inquiry(socket.assigns.inquiry, %{chapters: updated_chapters}) do
        {:ok, updated_inquiry} ->
          {:noreply,
           socket
           |> assign(:inquiry, updated_inquiry)
           |> assign(:chapters, updated_chapters)}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Error updating chapter type")}
      end
    else
      {:noreply, assign(socket, :chapters, updated_chapters)}
    end
  end

  def handle_event("set_time", %{"chapter-id" => chapter_id, "field" => field}, socket) do
    # This will be handled by the parent LiveView which knows the current video time
    send(self(), {:set_chapter_time, chapter_id, field})
    {:noreply, socket}
  end

  def handle_event("toggle_reviewed", %{"chapter-id" => chapter_id}, socket) do
    updated_chapters =
      update_in(
        socket.assigns.chapters,
        [chapter_id, "reviewed"],
        &(!&1)
      )

    send(self(), {:update_chapters, updated_chapters})

    {:noreply, assign(socket, :chapters, updated_chapters)}
  end

  def handle_event("delete_chapter", %{"chapter-id" => chapter_id}, socket) do
    updated_chapters = Map.delete(socket.assigns.chapters, chapter_id)
    send(self(), {:update_chapters, updated_chapters})

    {:noreply, assign(socket, :chapters, updated_chapters)}
  end

  def handle_event(
        "update_chapter_type",
        %{"chapter_id" => chapter_id, "type" => new_type},
        socket
      ) do
    IO.inspect(%{chapter_id: chapter_id, type: new_type}, label: "Update Chapter Type")

    updated_chapters =
      Map.update!(socket.assigns.chapters, chapter_id, fn chapter ->
        Map.put(chapter, "type", new_type)
      end)

    case Civicus.Inquiries.update_inquiry(socket.assigns.inquiry, %{chapters: updated_chapters}) do
      {:ok, updated_inquiry} ->
        {:noreply,
         socket
         |> assign(:inquiry, updated_inquiry)
         |> assign(:chapters, updated_chapters)}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error updating chapter type")}
    end
  end

  def handle_event(
        "update_timestamp",
        %{"chapter-id" => chapter_id, "field" => field, "value" => time_str},
        socket
      ) do
    case parse_timestamp(time_str) do
      {:ok, milliseconds} ->
        updated_chapters =
          Map.update!(socket.assigns.chapters, chapter_id, fn chapter ->
            Map.put(chapter, field, milliseconds)
          end)

        case Civicus.Inquiries.update_inquiry(socket.assigns.inquiry, %{
               chapters: updated_chapters
             }) do
          {:ok, updated_inquiry} ->
            {:noreply,
             socket
             |> assign(:inquiry, updated_inquiry)
             |> assign(:chapters, updated_chapters)}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Error updating timestamp")}
        end

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Invalid time format. Please use MM:SS")}
    end
  end

  defp generate_chapter_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp format_timestamp(milliseconds) when is_number(milliseconds) do
    seconds = div(trunc(milliseconds), 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    "#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(remaining_seconds), 2, "0")}"
  end

  defp format_timestamp(_), do: "00:00"

  defp parse_timestamp(time_str) do
    case String.split(time_str, ":") do
      [minutes_str, seconds_str] ->
        with {minutes, ""} <- Integer.parse(minutes_str),
             {seconds, ""} <- Integer.parse(seconds_str),
             true <- seconds >= 0 and seconds < 60,
             true <- minutes >= 0 do
          {:ok, (minutes * 60 + seconds) * 1000}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end
end
