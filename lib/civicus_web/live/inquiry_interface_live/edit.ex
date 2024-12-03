defmodule CivicusWeb.InquiryInterface.Edit do
  use CivicusWeb, :live_view

  alias Civicus.Inquiries
  alias CivicusWeb.Components.{HeaderNav, SidebarEditor, VideoPlayer}
  alias Phoenix.PubSub
  alias Civicus.Inquiries.Inquiry

  @impl true
  def mount(%{"slug" => "new"}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "New Inquiry")
     |> assign(:inquiry, %Inquiry{})
     |> assign(:progress, nil)
     |> assign(:transcribing?, false)
     |> assign(:form, to_form(Inquiries.change_inquiry(%Inquiry{})))}
  end

  def mount(%{"slug" => slug}, _session, socket) do
    case Inquiries.get_inquiry_by_slug(slug) do
      %Inquiry{} = inquiry ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Civicus.PubSub, "transcription:#{inquiry.id}")
          Phoenix.PubSub.subscribe(Civicus.PubSub, "transcription_progress:#{inquiry.id}")
        end

        {:ok,
         socket
         |> assign(:page_title, inquiry.name)
         |> assign(:inquiry, inquiry)
         |> assign(:progress, nil)
         |> assign(:transcribing?, false)
         |> assign(:current_time, 0)
         |> assign(:form, to_form(Inquiries.change_inquiry(inquiry)))}

      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Inquiry not found")
         |> redirect(to: ~p"/inquiries")}
    end
  end

  @impl true
  def handle_info({:transcription_started, _inquiry_id}, socket) do
    {:noreply,
     socket
     |> assign(:transcribing?, true)
     |> put_flash(:info, "Transcription started")}
  end

  @impl true
  def handle_info({:transcription_progress, message}, socket) do
    {:noreply, assign(socket, :progress, message)}
  end

  @impl true
  def handle_info(
        {:transcription_complete,
         %{transcript: transcript, structured_transcript: structured_transcript}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:transcribing?, false)
     |> assign(:progress, nil)
     |> assign(:inquiry, %{
       socket.assigns.inquiry
       | transcript: transcript,
         structured_transcript: structured_transcript
     })
     |> put_flash(:info, "Transcription completed")}
  end

  # Handle the case where we just get the transcript text
  def handle_info({:transcription_complete, transcript}, socket) when is_binary(transcript) do
    {:noreply,
     socket
     |> assign(:transcribing?, false)
     |> assign(:progress, nil)
     |> assign(:inquiry, %{
       socket.assigns.inquiry
       | transcript: transcript,
         structured_transcript: %{
           "utterances" => [
             %{
               "text" => transcript,
               "start" => 0,
               "speaker" => "Unknown"
             }
           ]
         }
     })
     |> put_flash(:info, "Transcription completed")}
  end

  @impl true
  def handle_info({:transcription_error, error}, socket) do
    {:noreply,
     socket
     |> assign(:transcribing?, false)
     |> assign(:progress, nil)
     |> put_flash(:error, "Transcription failed: #{error}")}
  end

  @impl true
  def handle_info({:save_inquiry, params}, socket) do
    case socket.assigns.inquiry.id do
      nil ->
        # Creating new inquiry
        case Inquiries.create_inquiry(params) do
          {:ok, inquiry} ->
            {:noreply,
             socket
             |> put_flash(:info, "Inquiry created successfully")
             |> redirect(to: ~p"/inquiry_interface/#{inquiry.slug}")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply,
             socket
             |> assign(:form, to_form(changeset))
             |> put_flash(:error, "Error creating inquiry")}
        end

      _id ->
        # Updating existing inquiry
        case Inquiries.update_inquiry(socket.assigns.inquiry, params) do
          {:ok, inquiry} ->
            {:noreply,
             socket
             |> put_flash(:info, "Inquiry updated successfully")
             |> assign(:inquiry, inquiry)
             |> assign(:form, to_form(Inquiries.change_inquiry(inquiry)))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply,
             socket
             |> assign(:form, to_form(changeset))
             |> put_flash(:error, "Error updating inquiry")}
        end
    end
  end

  @impl true
  def handle_event("save", %{"inquiry" => params}, socket) do
    case socket.assigns.inquiry.id do
      nil ->
        # Creating new inquiry
        case Inquiries.create_inquiry(params) do
          {:ok, inquiry} ->
            {:noreply,
             socket
             |> put_flash(:info, "Inquiry created successfully")
             |> redirect(to: ~p"/inquiry_interface/#{inquiry.slug}")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply,
             socket
             |> assign(:form, to_form(changeset))
             |> put_flash(:error, "Error creating inquiry")}
        end

      _id ->
        # Updating existing inquiry
        case Inquiries.update_inquiry(socket.assigns.inquiry, params) do
          {:ok, inquiry} ->
            {:noreply,
             socket
             |> put_flash(:info, "Inquiry updated successfully")
             |> assign(:inquiry, inquiry)
             |> assign(:form, to_form(Inquiries.change_inquiry(inquiry)))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply,
             socket
             |> assign(:form, to_form(changeset))
             |> put_flash(:error, "Error updating inquiry")}
        end
    end
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
  def handle_event("seek_video", %{"time" => time}, socket) do
    {time_ms, _} = Integer.parse(time)
    time_seconds = div(time_ms, 1000)

    {:noreply,
     socket
     |> push_event("seek_video", %{time: time_seconds})}
  end

  def format_timestamp(milliseconds) do
    seconds = div(milliseconds, 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    "#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(remaining_seconds), 2, "0")}"
  end
end
