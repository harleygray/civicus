defmodule CivicusWeb.InquiryInterface.Edit do
  use CivicusWeb, :live_view

  alias Civicus.Inquiries
  alias CivicusWeb.Components.{HeaderNav, InquiryEditor, VideoPlayer}
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
     |> assign(:current_time, 0)
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
         |> assign(:start_time, 0)
         |> assign(:end_time, 0)
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

  def format_timestamp(milliseconds) when is_number(milliseconds) do
    seconds = div(milliseconds, 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    "#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(remaining_seconds), 2, "0")}"
  end

  def format_timestamp(_), do: "00:00"

  def handle_info({:seek_video, time}, socket) do
    time_ms =
      case Integer.parse(time) do
        {val, _} -> val
        :error -> 0
      end

    {:noreply,
     socket
     |> assign(:current_time, time_ms)
     |> push_event("seek_video", %{time: div(time_ms, 1000)})}
  end

  def handle_info({:update_chapters, chapters}, socket) do
    case Inquiries.update_inquiry(socket.assigns.inquiry, %{chapters: chapters}) do
      {:ok, inquiry} ->
        {:noreply,
         socket
         |> assign(:inquiry, inquiry)
         |> put_flash(:info, "Chapters updated successfully")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error updating chapters")}
    end
  end

  def handle_info({:set_chapter_time, chapter_id, field}, socket) do
    current_time = socket.assigns.current_time

    updated_chapters =
      update_in(
        socket.assigns.inquiry.chapters,
        [chapter_id],
        &Map.put(&1, field, current_time)
      )

    case Inquiries.update_inquiry(socket.assigns.inquiry, %{chapters: updated_chapters}) do
      {:ok, inquiry} ->
        {:noreply,
         socket
         |> assign(:inquiry, inquiry)
         |> put_flash(:info, "Chapter time updated")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error updating chapter time")}
    end
  end

  def handle_info({:flash, {type, message}}, socket) do
    {:noreply, put_flash(socket, type, message)}
  end

  @impl true
  def handle_event("update_time_range", params, socket) do
    %{"value" => time_str, "target" => target} = params

    with {:ok, time_ms} <- parse_timestamp(time_str) do
      socket =
        case target do
          "start_time" -> assign(socket, :start_time, time_ms)
          "end_time" -> assign(socket, :end_time, time_ms)
          _ -> socket
        end

      require Logger

      Logger.info(
        "Updated time range - Start: #{socket.assigns.start_time}, End: #{socket.assigns.end_time}"
      )

      {:noreply, socket}
    else
      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Invalid time format. Please use MM:SS")}
    end
  end

  @impl true
  def handle_event("process_markers", _params, socket) do
    %{inquiry: inquiry, start_time: start_time, end_time: end_time} = socket.assigns

    case inquiry.structured_transcript do
      %{"utterances" => utterances} ->
        require Logger

        Logger.info(
          "Processing segments between #{format_timestamp(start_time)} and #{format_timestamp(end_time)}"
        )

        filtered_segments =
          utterances
          |> Enum.filter(fn utterance ->
            start = Map.get(utterance, "start", 0)
            # Convert float to integer if needed
            start = if is_float(start), do: trunc(start), else: start
            start >= start_time && start <= end_time
          end)
          |> Enum.map(fn utterance ->
            %{
              "speaker" => Map.get(utterance, "speaker", "Unknown"),
              "start" => Map.get(utterance, "start", 0),
              "text" => Map.get(utterance, "text", "")
            }
          end)

        Logger.info("Found #{length(filtered_segments)} segments")

        if Enum.empty?(filtered_segments) do
          {:noreply, put_flash(socket, :error, "No segments found in the selected time range")}
        else
          case Civicus.Transcript.TranscriptMarkers.process_segments(filtered_segments) do
            {:ok, markers} when is_list(markers) ->
              Logger.info("Processed #{length(markers)} markers")

              {:noreply,
               put_flash(socket, :info, "Successfully processed #{length(markers)} markers")}

            {:ok, _} ->
              {:noreply,
               put_flash(socket, :error, "Unexpected response format from marker processing")}

            {:error, error} ->
              {:noreply, put_flash(socket, :error, "Error processing markers: #{error}")}
          end
        end

      _ ->
        {:noreply, put_flash(socket, :error, "No transcript available")}
    end
  end

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
