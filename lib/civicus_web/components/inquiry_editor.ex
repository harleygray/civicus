defmodule CivicusWeb.Components.InquiryEditor do
  use CivicusWeb, :live_component
  alias Civicus.Inquiries

  @impl true
  def render(assigns) do
    ~H"""
    <div class="inquiry-editor-wrapper">
      <div class="inquiry-editor">
        <div class="fixed inset-y-0 left-0 w-96 bg-white border-r border-gray-200 flex flex-col">
          <div class="p-6 border-b border-gray-200 flex items-center justify-between">
            <h2 class="text-lg font-medium text-gray-900">Edit Inquiry</h2>
            <.link
              navigate={~p"/inquiries"}
              class="text-sm text-blue-600 hover:text-blue-800 hover:underline"
            >
              ← Back to Interface
            </.link>
          </div>

          <div class="flex-1 overflow-y-auto p-6">
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
                <%= if @inquiry.transcript do %>
                  <.button
                    type="button"
                    phx-click="delete_transcript"
                    phx-target={@myself}
                    data-confirm="Are you sure you want to delete this transcript? This cannot be undone."
                    class="button-danger"
                  >
                    Delete Transcript
                  </.button>
                <% end %>

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

            <.live_component
              module={CivicusWeb.Components.SpeakerEditor}
              id="speaker-editor"
              inquiry={@inquiry}
            />
          </div>
        </div>
      </div>
    </div>
    """
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

  @impl true
  def handle_event("delete_transcript", _params, socket) do
    case Inquiries.update_inquiry(socket.assigns.inquiry, %{
           transcript: nil,
           structured_transcript: nil,
           speaker_mappings: %{}
         }) do
      {:ok, updated_inquiry} ->
        {:noreply,
         socket
         |> assign(:inquiry, updated_inquiry)
         |> assign(:form, to_form(Inquiries.change_inquiry(updated_inquiry)))
         |> put_flash(:info, "Transcript deleted successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete transcript")}
    end
  end
end
