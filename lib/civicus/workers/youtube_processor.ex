defmodule Civicus.Workers.YoutubeProcessor do
  @moduledoc """
  This module processes YouTube videos by downloading the audio, uploading it to AssemblyAI, polling for the transcription, and updating the inquiry with the transcript.

  this youtube processor has gotten unweildy and complex. please refactor so that it correctly
  - downloads the youtube video
  - uploads it to assemblyai
  @  @https://www.postman.com/assembly-ai/assemblyai-pub/documentation/uxnikne/assemblyai-api?entity=request-30498076-304eb7f4-6c84-400c-8c50-fa23ac83924c
  - deletes the audio file
  - polls the appropriate assemblyai endpoint to get transcription status
  - once status is complete, add the transcript to the @inquiry.ex trnascript field
  - end the oban job

  analyse the whole @youtube_processor.ex file, then suggest changes. i want to use pubsub to broadcast updates using Logger to help with debugging
  """

  use Oban.Worker,
    queue: :media_processing,
    max_attempts: 5,
    unique: [period: 300, states: [:available, :scheduled, :executing]],
    tags: ["youtube", "transcription"]

  require Logger
  alias Phoenix.PubSub
  alias Civicus.Inquiries
  alias Civicus.Repo

  @assembly_ai_base_url "https://api.assemblyai.com"
  @assembly_ai_version "v2"
  @chunk_size 2048
  @max_file_size 1_000_000_000
  @max_polling_attempts 60

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"inquiry_id" => inquiry_id}} = job) do
    Logger.metadata(inquiry_id: inquiry_id, job_id: job.id, attempt: job.attempt)
    Logger.info("[Worker] Starting YouTube processing job")

    # Check if yt-dlp is installed
    case System.find_executable("yt-dlp") do
      nil ->
        error = "yt-dlp not found in system PATH"
        Logger.error("[Worker] #{error}")
        {:error, error}

      _path ->
        Logger.debug("[Worker] Found yt-dlp executable")
        process_job(inquiry_id)
    end
  end

  defp process_job(inquiry_id) do
    Logger.debug("[Worker] Processing job for inquiry: #{inquiry_id}")

    try do
      with {:ok, inquiry} <- fetch_inquiry(inquiry_id),
           _ <- Logger.debug("[Worker] Fetched inquiry: #{inspect(inquiry, pretty: true)}"),
           {:ok, audio_path} <- download_audio(inquiry.youtube_url, inquiry.id),
           _ <- Logger.debug("[Worker] Downloaded audio to: #{audio_path}"),
           {:ok, upload_url} <- upload_to_assembly_ai(audio_path, inquiry.id),
           _ <- Logger.debug("[Worker] Uploaded to AssemblyAI: #{upload_url}"),
           {:ok, transcript_id} <- start_transcription(upload_url, inquiry.id),
           _ <- Logger.debug("[Worker] Started transcription with ID: #{transcript_id}"),
           :ok <- File.rm(audio_path),
           _ <- Logger.debug("[Worker] Removed temporary audio file"),
           {:ok, transcript} <- poll_transcription(transcript_id, inquiry_id, 0) do
        # Update inquiry with transcript
        case update_inquiry_with_transcript(inquiry, transcript) do
          :ok ->
            broadcast_complete(inquiry_id, transcript)
            Logger.info("[Worker] Job completed successfully")
            :ok

          {:error, error} ->
            Logger.error("[Worker] Failed to update inquiry: #{inspect(error)}")
            handle_error(inquiry_id, error)
            {:error, error}
        end
      else
        {:error, error} ->
          Logger.error("[Worker] Job failed with error: #{inspect(error)}")
          handle_error(inquiry_id, error)
          {:error, error}

        {:snooze, delay} ->
          Logger.info("[Worker] Snoozing job for #{delay} seconds")
          {:snooze, delay}
      end
    rescue
      error ->
        Logger.error(
          "[Worker] Unexpected error in process_job: #{Exception.format(:error, error, __STACKTRACE__)}"
        )

        handle_error(inquiry_id, "Internal error: #{inspect(error)}")
        {:error, error}
    end
  end

  defp fetch_inquiry(inquiry_id) do
    try do
      case Inquiries.get_inquiry!(inquiry_id) do
        %Civicus.Inquiries.Inquiry{} = inquiry ->
          Logger.info("[Worker] Found inquiry: #{inquiry.id}")
          {:ok, inquiry}

        other ->
          Logger.error("[Worker] Unexpected inquiry format: #{inspect(other)}")
          {:error, :invalid_inquiry_format}
      end
    rescue
      Ecto.NoResultsError ->
        Logger.error("[Worker] Inquiry not found: #{inquiry_id}")
        {:error, :inquiry_not_found}

      error ->
        Logger.error("[Worker] Error fetching inquiry: #{inspect(error)}")
        {:error, :inquiry_fetch_failed}
    end
  end

  defp download_audio(youtube_url, inquiry_id) do
    static_path = Path.join(["priv", "static", "audio"])
    File.mkdir_p!(static_path)
    output_path = Path.join(static_path, "#{inquiry_id}.m4a")

    if File.exists?(output_path) do
      Logger.info("Using cached audio file")
      broadcast_progress(inquiry_id, "Using cached audio")
      {:ok, output_path}
    else
      Logger.info("Starting audio download from YouTube: #{youtube_url}")
      download_and_save_audio(youtube_url, output_path, inquiry_id)
    end
  end

  defp download_and_save_audio(url, output_path, inquiry_id) do
    Logger.info("Starting audio download from YouTube")
    broadcast_progress(inquiry_id, "Downloading audio")

    args = [
      "-f",
      "ba[ext=m4a]",
      "-o",
      output_path,
      "--no-playlist",
      "--force-ipv4",
      "--verbose",
      url
    ]

    Logger.debug("[yt-dlp] Command: yt-dlp #{Enum.join(args, " ")}")

    case System.cmd("yt-dlp", args, stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("Audio download successful")
        Logger.debug("[yt-dlp] Raw output:\n#{output}")
        broadcast_progress(inquiry_id, "Audio downloaded")
        {:ok, output_path}

      {output, code} ->
        error_msg = "yt-dlp failed with code #{code}"
        Logger.error(error_msg)
        Logger.error("[yt-dlp] Error output:\n#{output}")
        broadcast_error(inquiry_id, "Audio download failed")
        {:error, error_msg}
    end
  end

  defp upload_to_assembly_ai(audio_path, inquiry_id) do
    Logger.info("Starting upload to AssemblyAI")
    broadcast_progress(inquiry_id, "Uploading to transcription service")

    url = "#{@assembly_ai_base_url}/#{@assembly_ai_version}/upload"
    headers = build_headers()

    Logger.debug("[AssemblyAI] Upload request URL: #{url}")
    Logger.debug("[AssemblyAI] Headers: #{inspect(headers, pretty: true)}")

    with {:ok, %{size: size}} <- File.stat(audio_path),
         :ok <- validate_file_size(size),
         stream = File.stream!(audio_path, [:read], @chunk_size),
         {:ok, %{"upload_url" => upload_url}} <- make_upload_request(url, stream, headers) do
      Logger.info("Upload successful")
      Logger.debug("[AssemblyAI] Upload URL received: #{upload_url}")
      broadcast_progress(inquiry_id, "Upload complete")
      {:ok, upload_url}
    else
      {:error, error} ->
        Logger.error("Upload failed: #{inspect(error)}")
        Logger.error("[AssemblyAI] Upload error details: #{inspect(error, pretty: true)}")
        broadcast_error(inquiry_id, "Upload failed")
        {:error, error}
    end
  end

  defp build_headers do
    [
      {"authorization", assembly_ai_key()},
      {"transfer-encoding", "chunked"},
      {"content-type", "audio/x-m4a"}
    ]
  end

  defp validate_file_size(size) when size > @max_file_size do
    Logger.error("File size exceeds maximum allowed: #{size} bytes")
    {:error, "File too large (> 1GB)"}
  end

  defp validate_file_size(size) do
    Logger.info("File size valid: #{size} bytes")
    :ok
  end

  defp make_upload_request(url, stream, headers) do
    Logger.debug("[AssemblyAI] Making upload request to #{url}")

    case HTTPoison.post(url, {:stream, stream}, headers,
           timeout: 60_000,
           recv_timeout: 60_000,
           hackney: [pool: false]
         ) do
      {:ok, response} ->
        Logger.debug("[AssemblyAI] Raw upload response: #{inspect(response, pretty: true)}")
        parse_response({:ok, response})

      {:error, error} ->
        Logger.error("[AssemblyAI] Upload request error: #{inspect(error, pretty: true)}")
        parse_response({:error, error})
    end
  end

  defp parse_response({:ok, %HTTPoison.Response{status_code: status_code, body: body}} = response)
       when status_code in 200..299 do
    Logger.debug("Parsing successful response: #{inspect(response, pretty: true)}")

    case Jason.decode(body) do
      {:ok, decoded} ->
        {:ok, decoded}

      {:error, error} ->
        Logger.error("Failed to decode response: #{inspect(error)}")
        {:error, "Failed to decode response"}
    end
  end

  defp parse_response({:ok, %HTTPoison.Response{status_code: status_code, body: body}}) do
    error_msg = "Request failed with status #{status_code}: #{body}"
    Logger.error(error_msg)
    {:error, error_msg}
  end

  defp parse_response({:error, %HTTPoison.Error{reason: reason}}) do
    error_msg = "HTTP request failed: #{inspect(reason)}"
    Logger.error(error_msg)
    {:error, error_msg}
  end

  defp parse_response(unexpected) do
    Logger.error("Unexpected response format: #{inspect(unexpected, pretty: true)}")
    {:error, "Unexpected response format"}
  end

  defp start_transcription(upload_url, inquiry_id) do
    Logger.info("Starting transcription process")
    broadcast_progress(inquiry_id, "Starting transcription")

    url = "#{@assembly_ai_base_url}/#{@assembly_ai_version}/transcript"
    headers = [{"authorization", assembly_ai_key()}, {"content-type", "application/json"}]

    body =
      Jason.encode!(%{
        audio_url: upload_url,
        speaker_labels: true,
        language_code: "en",
        punctuate: true,
        format_text: true
      })

    Logger.debug("[AssemblyAI] Transcription request URL: #{url}")
    Logger.debug("[AssemblyAI] Request body: #{body}")

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} = response ->
        Logger.debug(
          "[AssemblyAI] Raw transcription response: #{inspect(response, pretty: true)}"
        )

        Logger.debug("[AssemblyAI] Response body: #{response_body}")

        case Jason.decode(response_body) do
          {:ok, %{"id" => transcript_id}} ->
            Logger.info("[AssemblyAI] Transcription started with ID: #{transcript_id}")
            {:ok, transcript_id}

          {:ok, decoded} ->
            Logger.error(
              "[AssemblyAI] Unexpected response structure: #{inspect(decoded, pretty: true)}"
            )

            {:error, "Unexpected response structure"}

          {:error, error} ->
            Logger.error("[AssemblyAI] Failed to decode response: #{inspect(error)}")
            {:error, "Failed to decode response"}
        end

      {:ok, response} ->
        Logger.error("[AssemblyAI] Unexpected status code: #{inspect(response, pretty: true)}")
        {:error, "Unexpected status code"}

      {:error, error} ->
        Logger.error("[AssemblyAI] Request failed: #{inspect(error)}")
        {:error, "Request failed"}
    end
  end

  defp poll_transcription(transcript_id, inquiry_id, attempt)
       when attempt >= @max_polling_attempts do
    error = "Transcription timed out after #{@max_polling_attempts} attempts"
    Logger.error("[AssemblyAI] #{error}")
    broadcast_error(inquiry_id, error)
    {:error, error}
  end

  defp poll_transcription(transcript_id, inquiry_id, attempt) do
    url = "#{@assembly_ai_base_url}/#{@assembly_ai_version}/transcript/#{transcript_id}"
    headers = [{"authorization", assembly_ai_key()}]

    Logger.debug("[AssemblyAI] Polling attempt #{attempt + 1}/#{@max_polling_attempts}")
    Logger.debug("[AssemblyAI] Polling URL: #{url}")

    # Calculate backoff time (5s, 10s, 15s, etc.)
    timeout = min(5000 * (attempt + 1), 30_000)

    case HTTPoison.get(url, headers,
           timeout: timeout,
           recv_timeout: timeout,
           hackney: [pool: false]
         ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Logger.debug("[AssemblyAI] Raw polling response: #{body}")

        case Jason.decode(body) do
          {:ok, %{"status" => "completed", "text" => transcript}} ->
            Logger.info("[AssemblyAI] Transcription completed successfully")
            broadcast_progress(inquiry_id, "Transcription complete")
            {:ok, transcript}

          {:ok, %{"status" => "error", "error" => error}} ->
            Logger.error("[AssemblyAI] Transcription failed with error: #{error}")
            broadcast_error(inquiry_id, "Transcription failed: #{error}")
            {:error, error}

          {:ok, %{"status" => status}} ->
            Logger.info(
              "[AssemblyAI] Transcription status: #{status} (attempt #{attempt + 1}/#{@max_polling_attempts})"
            )

            broadcast_progress(inquiry_id, "Transcription in progress: #{status}")

            # Exponential backoff sleep
            backoff = min(5000 * (attempt + 1), 30_000)
            Process.sleep(backoff)

            poll_transcription(transcript_id, inquiry_id, attempt + 1)

          {:error, error} ->
            Logger.error("[AssemblyAI] Failed to decode polling response: #{inspect(error)}")
            broadcast_error(inquiry_id, "Failed to decode response")
            {:error, error}
        end

      {:error, %HTTPoison.Error{reason: :timeout}} ->
        Logger.error("[AssemblyAI] Polling request timed out, retrying with longer timeout")
        # On timeout, retry immediately with increased timeout
        Process.sleep(1000)
        poll_transcription(transcript_id, inquiry_id, attempt + 1)

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("[AssemblyAI] Polling request failed: #{inspect(reason)}")

        if retryable_error?(reason) do
          Logger.info("[AssemblyAI] Retrying after error")
          Process.sleep(5000)
          poll_transcription(transcript_id, inquiry_id, attempt + 1)
        else
          broadcast_error(inquiry_id, "Polling request failed")
          {:error, reason}
        end
    end
  end

  defp retryable_error?(:timeout), do: true
  defp retryable_error?(:econnrefused), do: true
  defp retryable_error?(:closed), do: true
  defp retryable_error?(_), do: false

  defp update_inquiry_with_transcript(inquiry, transcript) do
    case Inquiries.update_inquiry(inquiry, %{transcript: transcript, status: "completed"}) do
      {:ok, _} ->
        Logger.info("Transcript saved to inquiry")
        :ok

      {:error, error} ->
        Logger.error("Failed to save transcript to inquiry: #{inspect(error)}")
        {:error, error}
    end
  end

  defp handle_error(inquiry_id, error) do
    Logger.error("Processing failed: #{inspect(error)}")
    broadcast_error(inquiry_id, "Processing failed")
  end

  defp broadcast_progress(inquiry_id, message) do
    Logger.debug("Broadcasting progress: #{message}")

    PubSub.broadcast(
      Civicus.PubSub,
      "transcription_progress:#{inquiry_id}",
      {:transcription_progress, message}
    )
  end

  defp broadcast_complete(inquiry_id, transcript) do
    Logger.info("Broadcasting completion")

    PubSub.broadcast(
      Civicus.PubSub,
      "transcription:#{inquiry_id}",
      {:transcription_complete, transcript}
    )
  end

  defp broadcast_error(inquiry_id, error) do
    Logger.error("Broadcasting error: #{inspect(error)}")
    PubSub.broadcast(Civicus.PubSub, "transcription:#{inquiry_id}", {:transcription_error, error})
  end

  defp assembly_ai_key, do: Application.fetch_env!(:civicus, :assembly_ai_key)

  def debug_job_status(inquiry_id) do
    case Repo.get_by(Oban.Job,
           queue: "media_processing",
           args: %{"inquiry_id" => inquiry_id}
         ) do
      nil ->
        Logger.error("No job found for inquiry #{inquiry_id}")
        {:error, :job_not_found}

      job ->
        Logger.info("Job status for inquiry #{inquiry_id}: #{inspect(job.state)}")
        {:ok, job}
    end
  end
end
