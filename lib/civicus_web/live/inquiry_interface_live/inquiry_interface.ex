defmodule CivicusWeb.InquiryInterface do
  use CivicusWeb, :live_view
  alias CivicusWeb.Components.HeaderNav, as: HeaderNav
  alias Civicus.Inquiries
  alias Civicus.Inquiries.Inquiry
  require Logger

  @inquiry_statuses ["pending", "work_in_progress", "published"]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to progress updates for all inquiries
      for inquiry <- list_inquiries() do
        Phoenix.PubSub.subscribe(Civicus.PubSub, "transcription_progress:#{inquiry.id}")
      end
    end

    {:ok,
     assign(socket,
       page_title: "Inquiry Interface",
       inquiries: list_inquiries(),
       changeset: Inquiries.change_inquiry(%Inquiry{}),
       show_form: false,
       show_advanced: false,
       editing_inquiry: nil,
       current_time: 0,
       timestamp: :os.system_time(:millisecond),
       statuses: @inquiry_statuses,
       selected_inquiry: nil,
       show_progress: false,
       progress_inquiry_id: nil,
       # Store messages by inquiry_id
       progress_messages: %{}
     )}
  end

  @impl true
  def handle_event("toggle_advanced", _, socket) do
    {:noreply, assign(socket, show_advanced: !socket.assigns.show_advanced)}
  end

  @impl true
  def handle_event("start_transcription", %{"id" => id}, socket) when not is_nil(id) do
    Logger.info("Starting transcription for inquiry #{id}")

    case %{inquiry_id: id}
         |> Civicus.Workers.YoutubeProcessor.new()
         |> Oban.insert() do
      {:ok, _job} ->
        Logger.info("Successfully queued Oban job for inquiry #{id}")
        inquiry = Inquiries.get_inquiry!(id)
        {:ok, _inquiry} = Inquiries.update_inquiry(inquiry, %{status: "work_in_progress"})

        {:noreply,
         socket
         |> put_flash(:info, "Transcription started - this may take a few minutes")
         |> assign(:inquiries, Inquiries.list_inquiries())
         |> assign(:show_progress, true)
         |> assign(:progress_inquiry_id, id)}

      {:error, error} ->
        Logger.error("Failed to queue Oban job: #{inspect(error)}")
        {:noreply, socket |> put_flash(:error, "Failed to start transcription")}
    end
  end

  # Handle case when id is nil
  def handle_event("start_transcription", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Cannot start transcription - no inquiry selected")}
  end

  @impl true
  def handle_event("select_inquiry", %{"id" => id}, socket) do
    inquiry = Inquiries.get_inquiry!(id)
    {:noreply, assign(socket, selected_inquiry: inquiry)}
  end

  @impl true
  def handle_event("new_inquiry", _, socket) do
    {:noreply,
     assign(socket,
       show_form: true,
       show_advanced: false,
       changeset: Inquiries.change_inquiry(%Inquiry{}),
       editing_inquiry: nil,
       preview_url: nil,
       preview_inquiry: nil
     )}
  end

  @impl true
  def handle_event("edit_inquiry", %{"id" => id}, socket) do
    inquiry = Inquiries.get_inquiry!(id)
    changeset = Inquiries.change_inquiry(inquiry)

    {:noreply,
     assign(socket,
       show_form: true,
       show_advanced: true,
       changeset: changeset,
       editing_inquiry: inquiry
     )}
  end

  @impl true
  def handle_event("update_status", %{"status" => status, "id" => id}, socket) do
    inquiry = Inquiries.get_inquiry!(id)

    case Inquiries.update_inquiry(inquiry, %{status: status}) do
      {:ok, updated_inquiry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Status updated successfully")
         |> assign(:inquiries, list_inquiries())
         |> assign(
           :selected_inquiry,
           if(socket.assigns.selected_inquiry && socket.assigns.selected_inquiry.id == id,
             do: updated_inquiry,
             else: socket.assigns.selected_inquiry
           )
         )}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update status")}
    end
  end

  @impl true
  def handle_event("preview_youtube", %{"inquiry" => params}, socket) do
    if _embed_url = params["youtube_embed"],
      do: do_preview(socket, params),
      else: {:noreply, socket}
  end

  @impl true
  def handle_event("cancel", _, socket) do
    {:noreply,
     assign(socket,
       show_form: false,
       show_advanced: false,
       editing_inquiry: nil,
       preview_inquiry: nil
     )}
  end

  def handle_event("save", %{"inquiry" => params}, socket) do
    # Convert comma-separated senators to list
    params = Map.update(params, "senators", [], &string_to_list/1)

    case socket.assigns.editing_inquiry do
      nil -> create_inquiry(socket, params)
      inquiry -> update_inquiry(socket, inquiry, params)
    end
  end

  defp string_to_list(""), do: []

  defp string_to_list(string) when is_binary(string) do
    string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp string_to_list(list) when is_list(list), do: list

  @impl true
  def handle_info(:hide_progress, socket) do
    {:noreply, assign(socket, show_progress: false)}
  end

  @impl true
  def handle_info({:transcription_progress, message}, socket) do
    # Get the inquiry_id from the PubSub topic
    inquiry_id =
      case Process.get(:"$pubsub_subscription") do
        "transcription_progress:" <> id -> id
        _ -> nil
      end

    if inquiry_id do
      messages = Map.get(socket.assigns.progress_messages, inquiry_id, [])
      updated_messages = [message | messages] |> Enum.take(5)

      {:noreply,
       assign(socket,
         progress_messages:
           Map.put(socket.assigns.progress_messages, inquiry_id, updated_messages)
       )}
    else
      {:noreply, socket}
    end
  end

  # Catch-all handler for other messages
  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  defp list_inquiries do
    Inquiries.list_inquiries()
  end

  # Helper function to parse date
  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_senators(nil), do: []
  defp parse_senators(""), do: []

  defp parse_senators(senators_string) when is_binary(senators_string) do
    senators_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp do_preview(socket, params) do
    preview_inquiry = %Inquiry{
      youtube_embed: params["youtube_embed"],
      youtube_url: params["youtube_url"] || "",
      name: params["name"] || "",
      committee: params["committee"] || "",
      date_held: parse_date(params["date_held"]) || Date.utc_today(),
      status: "pending",
      transcript: nil,
      senators: parse_senators(params["senators"])
    }

    {:noreply, assign(socket, preview_inquiry: preview_inquiry)}
  end

  defp create_inquiry(socket, params) do
    case Inquiries.create_inquiry(params) do
      {:ok, _inquiry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Inquiry created successfully")
         |> assign(:inquiries, list_inquiries())
         |> assign(:show_form, false)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp update_inquiry(socket, inquiry, params) do
    case Inquiries.update_inquiry(inquiry, params) do
      {:ok, _inquiry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Inquiry updated successfully")
         |> assign(:inquiries, list_inquiries())
         |> assign(:show_form, false)
         |> assign(:editing_inquiry, nil)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
