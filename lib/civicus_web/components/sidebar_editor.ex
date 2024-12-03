defmodule CivicusWeb.Components.SidebarEditor do
  use CivicusWeb, :live_component
  alias Civicus.Inquiries
  alias Phoenix.LiveView.JS

  def render(assigns) do
    ~H"""
    <div class="sidebar-editor-wrapper">
      <div class="sidebar-editor">
        <div class={"fixed inset-y-0 left-0 w-96 bg-white border-r border-gray-200 transform transition-transform duration-300 #{if @minimized?, do: "-translate-x-96", else: "translate-x-0"}"}>
          <div class="p-6 space-y-6">
            <div class="flex items-center justify-between">
              <h2 class="text-lg font-medium text-gray-900">Edit Inquiry</h2>
              <div class="flex space-x-2">
                <button
                  type="button"
                  class="fixed top-20 left-4 p-2 bg-white rounded-md shadow-lg hover:bg-gray-50 z-50"
                  phx-click="toggle_sidebar"
                  phx-target={@myself}
                >
                  <span class="sr-only">Toggle sidebar</span>
                  <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M4 6h16M4 12h16M4 18h16"
                    />
                  </svg>
                </button>
                <button
                  type="button"
                  class="text-gray-400 hover:text-gray-500"
                  phx-click="close_sidebar"
                  phx-target={@myself}
                >
                  <span class="sr-only">Close sidebar</span>
                  <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
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

            <.form
              for={@form}
              phx-change="validate"
              phx-submit="save"
              phx-target={@myself}
              class="space-y-6"
            >
              <div class="space-y-4">
                <div>
                  <.input field={@form[:name]} type="text" label="Name" />
                </div>

                <div>
                  <.input field={@form[:slug]} type="text" label="Slug" />
                </div>

                <div>
                  <.input field={@form[:youtube_embed]} type="text" label="YouTube Embed URL" />
                </div>

                <div>
                  <.input field={@form[:youtube_url]} type="text" label="YouTube URL" />
                </div>

                <div>
                  <.input field={@form[:committee]} type="text" label="Committee" />
                </div>

                <div>
                  <.input field={@form[:date_held]} type="date" label="Date Held" />
                </div>

                <div>
                  <.input
                    field={@form[:status]}
                    type="select"
                    label="Status"
                    options={[
                      {"Pending", "pending"},
                      {"Downloading", "downloading"},
                      {"Uploading", "uploading"},
                      {"Transcribing", "transcribing"},
                      {"Completed", "completed"},
                      {"Failed", "failed"}
                    ]}
                  />
                </div>
              </div>

              <div class="flex justify-end space-x-3 pt-6 border-t border-gray-200">
                <.button
                  type="button"
                  phx-click="transcribe"
                  phx-target={@myself}
                  disabled={@transcribing?}
                  class="button-gradient"
                >
                  <%= if @transcribing?, do: "Transcribing...", else: "Start Transcription" %>
                </.button>
                <.button type="submit" phx-disable-with="Saving..." class="button-gradient">
                  Save Changes
                </.button>
              </div>
            </.form>
          </div>
        </div>
      </div>

      <%= if @minimized? do %>
        <button
          type="button"
          class="fixed top-20 left-4 p-2 bg-white rounded-md shadow-lg hover:bg-gray-50"
          phx-click="toggle_sidebar"
          phx-target={@myself}
        >
          <svg class="h-6 w-6 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M4 6h16M4 12h16M4 18h16"
            />
          </svg>
        </button>
      <% end %>
    </div>
    """
  end

  def mount(socket) do
    {:ok, assign(socket, minimized?: false)}
  end

  @impl true
  def handle_event("validate", %{"inquiry" => params}, socket) do
    changeset =
      socket.assigns.inquiry
      |> Inquiries.change_inquiry(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"inquiry" => params}, socket) do
    # Send the save event to the parent LiveView instead of handling it here
    send(self(), {:save_inquiry, params})
    {:noreply, socket}
  end

  def handle_event("transcribe", _params, socket) do
    case Civicus.Inquiries.start_transcription(socket.assigns.inquiry) do
      {:ok, _inquiry} ->
        {:noreply,
         socket
         |> assign(:transcribing?, true)
         |> put_flash(:info, "Transcription started")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to start transcription: #{inspect(reason)}")}
    end
  end

  def handle_event("close_sidebar", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/inquiry_interface")}
  end

  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, minimized?: !socket.assigns.minimized?)}
  end
end
