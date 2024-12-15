defmodule Civicus.Workers.YoutubeProcessor do
  use Oban.Worker,
    queue: :media_processing,
    max_attempts: 3,
    unique: [period: 30]

  require Logger
  alias Phoenix.PubSub
  alias Civicus.Inquiries

  @deepgram_api_url "https://api.deepgram.com/v1/listen"

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"inquiry_id" => inquiry_id}}) do
    try do
      with {:ok, inquiry} <- fetch_inquiry(inquiry_id),
           _ <- Logger.debug("[Worker] Found inquiry: #{inspect(inquiry)}"),
           {:ok, audio_path} <- download_audio(inquiry.youtube_url, inquiry.id),
           _ <- Logger.debug("[Worker] Downloaded audio to: #{audio_path}"),
           {:ok, transcript} <- transcribe_with_deepgram(audio_path, inquiry.id),
           _ <- Logger.debug("[Worker] Transcribed audio"),
           :ok <- File.rm(audio_path),
           _ <- Logger.debug("[Worker] Removed temporary audio file") do
        # Update inquiry with transcript
        case update_inquiry_with_transcript(inquiry, transcript) do
          :ok ->
            Logger.info("[Worker] Successfully processed inquiry #{inquiry_id}")
            :ok

          {:error, reason} ->
            Logger.error("[Worker] Failed to update inquiry: #{inspect(reason)}")
            {:error, reason}
        end
      else
        {:error, reason} ->
          Logger.error("[Worker] Job failed: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      error ->
        Logger.error("[Worker] Unexpected error: #{inspect(error)}")
        {:error, error}
    end
  end

  defp fetch_inquiry(inquiry_id) do
    try do
      inquiry = Inquiries.get_inquiry!(inquiry_id)
      {:ok, inquiry}
    rescue
      Ecto.NoResultsError -> {:error, "Inquiry not found"}
    end
  end

  defp download_audio(youtube_url, inquiry_id) do
    output_path = "priv/static/audio/audio_#{inquiry_id}.mp3"
    File.mkdir_p!("priv/static/audio")

    broadcast_progress(inquiry_id, "Downloading audio")
    Logger.info("[Worker] Starting audio download from YouTube: #{youtube_url}")

    args = [
      "-x",
      "--audio-format",
      "mp3",
      "--audio-quality",
      "0",
      "-o",
      output_path,
      youtube_url
    ]

    case System.cmd("yt-dlp", args, stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("[Worker] Audio download successful to: #{output_path}")
        Logger.debug("[yt-dlp] Raw output:\n#{output}")
        broadcast_progress(inquiry_id, "Audio downloaded")
        {:ok, output_path}

      {output, code} ->
        error_msg = "yt-dlp failed with code #{code}"
        Logger.error("[Worker] #{error_msg}")
        Logger.error("[yt-dlp] Error output:\n#{output}")
        broadcast_error(inquiry_id, "Audio download failed")
        {:error, error_msg}
    end
  end

  defp transcribe_with_deepgram(audio_path, inquiry_id) do
    Logger.info("[Worker] Starting Deepgram transcription for inquiry #{inquiry_id}")
    broadcast_progress(inquiry_id, "Starting transcription")

    # Verify file exists and is readable
    case File.stat(audio_path) do
      {:ok, %{size: size}} ->
        Logger.info("[Worker] Audio file size: #{size} bytes")
        if size == 0, do: Logger.error("[Worker] Audio file is empty")

      {:error, reason} ->
        Logger.error("[Worker] Failed to stat audio file: #{inspect(reason)}")
        raise "Audio file not accessible: #{reason}"
    end

    # Read file content
    Logger.debug("[Worker] Reading audio file: #{audio_path}")

    case File.read(audio_path) do
      {:ok, audio_content} ->
        Logger.info("[Worker] Successfully read audio file (#{byte_size(audio_content)} bytes)")

        headers = [
          {"Authorization", "Token #{deepgram_api_key()}"},
          {"Content-Type", "audio/mp3"}
        ]

        params = %{
          punctuate: true,
          diarize: true,
          utterances: true,
          paragraphs: true,
          language: "en-AU",
          model: "nova-2",
          smart_format: true
        }

        url = "#{@deepgram_api_url}?#{URI.encode_query(params)}"
        Logger.debug("[Worker] Sending request to Deepgram: #{url}")

        # 30 minutes timeout
        case HTTPoison.post(url, audio_content, headers,
               timeout: 1_800_000,
               recv_timeout: 1_800_000
             ) do
          {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
            case Jason.decode(body) do
              {:ok, response} ->
                case response do
                  %{"results" => %{"channels" => [%{"alternatives" => [%{"transcript" => ""}]}]}} ->
                    Logger.error("[Worker] Received empty transcript from Deepgram")
                    {:error, "Empty transcript received"}

                  %{
                    "results" => %{
                      "channels" => [%{"alternatives" => [%{"transcript" => transcript} | _]}]
                    }
                  } ->
                    Logger.info(
                      "[Worker] Successfully received transcript of length: #{String.length(transcript)}"
                    )

                    {:ok, process_deepgram_response(response)}

                  _ ->
                    Logger.error(
                      "[Worker] Unexpected response format: #{inspect(response, pretty: true)}"
                    )

                    {:error, "Unexpected response format"}
                end

              {:error, error} ->
                Logger.error("[Worker] Failed to decode Deepgram response: #{inspect(error)}")
                {:error, "Failed to decode response"}
            end

          {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
            Logger.error("[Worker] Deepgram API error: #{status_code} - #{body}")
            {:error, "API error: #{status_code}"}

          {:error, error} ->
            Logger.error("[Worker] HTTP request failed: #{inspect(error)}")
            {:error, "HTTP request failed"}
        end

      {:error, reason} ->
        Logger.error("[Worker] Failed to read audio file: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_deepgram_response(%{"results" => results}) do
    alternatives = get_in(results, ["channels", Access.at(0), "alternatives", Access.at(0)])

    # Get paragraphs data if available, otherwise fall back to words
    utterances =
      case alternatives do
        %{"paragraphs" => %{"paragraphs" => paragraphs}} ->
          # Flatten all sentences from all paragraphs
          paragraphs
          |> Enum.flat_map(fn paragraph ->
            paragraph["sentences"]
            |> Enum.map(fn sentence ->
              # Find the speaker for this time range from the words array
              speaker =
                find_speaker_for_timerange(
                  alternatives["words"],
                  sentence["start"],
                  sentence["end"]
                )

              %{
                "text" => sentence["text"],
                # Convert to ms
                "start" => trunc(sentence["start"] * 1000),
                "speaker" => "Speaker #{speaker}"
              }
            end)
          end)

        _ ->
          # Fall back to original speaker-based chunking
          words = alternatives["words"] || []

          Enum.chunk_by(words, & &1["speaker"])
          |> Enum.map(fn words ->
            %{
              "text" => Enum.map_join(words, " ", & &1["word"]),
              "start" => List.first(words)["start"] * 1000,
              "speaker" => "Speaker #{List.first(words)["speaker"]}"
            }
          end)
      end

    %{
      "text" => alternatives["transcript"],
      "utterances" => utterances,
      "auto_highlights_result" => nil
    }
  end

  # Helper function to find the most common speaker in a time range
  defp find_speaker_for_timerange(words, start_time, end_time) do
    words
    |> Enum.filter(fn word ->
      word["start"] >= start_time && word["start"] <= end_time
    end)
    |> Enum.group_by(& &1["speaker"])
    |> Enum.max_by(fn {_speaker, words} -> length(words) end, fn -> {0, []} end)
    |> elem(0)
  end

  defp update_inquiry_with_transcript(inquiry, transcript) do
    case Inquiries.update_inquiry(inquiry, %{
           transcript: transcript["text"],
           structured_transcript: transcript,
           status: "completed"
         }) do
      {:ok, _updated_inquiry} ->
        broadcast_progress(inquiry.id, "Transcription completed")
        :ok

      {:error, error} ->
        Logger.error("[Worker] Failed to save transcript: #{inspect(error)}")
        {:error, error}
    end
  end

  defp broadcast_progress(inquiry_id, message) do
    Logger.debug("Broadcasting progress: #{message}")

    PubSub.broadcast(
      Civicus.PubSub,
      "transcription:#{inquiry_id}",
      {:transcription_progress, message}
    )
  end

  defp broadcast_error(inquiry_id, error) do
    Logger.error("Broadcasting error: #{inspect(error)}")
    PubSub.broadcast(Civicus.PubSub, "transcription:#{inquiry_id}", {:transcription_error, error})
  end

  defp deepgram_api_key, do: Application.fetch_env!(:civicus, :deepgram_api_key)
end
