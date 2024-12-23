defmodule Civicus.Transcript.TranscriptMarkers do
  @moduledoc """
  Module for identifying and processing transcript markers in parliamentary transcripts.
  Markers help identify different types of segments like questions, procedures, and testimonies.
  """

  alias Civicus.LLM.GroqClient

  defmodule MarkerType do
    @moduledoc "Defines the types of markers that can be identified in a transcript"

    @type t :: :question | :opening_statement | :procedure | :testimony

    def all, do: [:question, :opening_statement, :procedure, :testimony]
  end

  defmodule Question do
    @moduledoc "Structure for question-type markers"

    @type t :: %__MODULE__{
            question: String.t(),
            answer: String.t() | nil,
            who_is_asking: String.t() | nil,
            who_is_being_asked: String.t() | nil
          }

    defstruct [:question, :answer, :who_is_asking, :who_is_being_asked]
  end

  defmodule Testimony do
    @moduledoc "Structure for testimony-type markers"

    @type t :: %__MODULE__{
            speaker_name: String.t() | nil,
            speaker_role: String.t() | nil,
            speaker_organization: String.t() | nil,
            testimony_title: String.t()
          }

    defstruct [:speaker_name, :speaker_role, :speaker_organization, :testimony_title]
  end

  defmodule OpeningStatement do
    @moduledoc "Structure for opening statement markers"

    @type t :: %__MODULE__{
            speaker_name: String.t() | nil,
            opening_statement_title: String.t()
          }

    defstruct [:speaker_name, :opening_statement_title]
  end

  defmodule Procedure do
    @moduledoc "Structure for procedure-type markers"

    @type t :: %__MODULE__{
            procedure_title: String.t()
          }

    defstruct [:procedure_title]
  end

  defmodule TranscriptMarker do
    @moduledoc "Main structure for transcript markers"

    @type t :: %__MODULE__{
            marker_type: MarkerType.t(),
            sentence_number: String.t(),
            marker_information:
              Question.t() | Testimony.t() | OpeningStatement.t() | Procedure.t()
          }

    defstruct [:marker_type, :sentence_number, :marker_information]
  end

  @doc """
  Processes a list of transcript segments and identifies markers within them.

  ## Parameters
    - segments: List of transcript segments with speaker, start time, and text

  ## Returns
    - {:ok, list(TranscriptMarker.t())} on success
    - {:error, String.t()} on failure
  """
  @spec process_segments(list(map())) :: {:ok, list(TranscriptMarker.t())} | {:error, String.t()}
  def process_segments(segments) do
    case Civicus.LLM.GroqClient.chat_completion(prepare_messages(segments)) do
      {:ok, response} ->
        case parse_llm_response(response) do
          {:ok, markers} -> {:ok, markers}
          {:error, reason} -> {:error, "Failed to parse LLM response: #{reason}"}
        end

      {:error, error} ->
        {:error, "LLM request failed: #{error}"}
    end
  end

  defp prepare_messages(segments) do
    content = format_segments_for_llm(segments)

    [
      %{
        role: "system",
        content: """
        You are an expert at analyzing Australian parliamentary transcripts. Your task is to identify and classify different types of segments in the transcript.

        You must respond with a JSON object in this exact format:
        {
          "transcript_markers": [
            {
              "marker_type": "QUESTION"|"OPENING_STATEMENT"|"PROCEDURE"|"TESTIMONY",
              "sentence_number": "The time marker where the transcript marker occurs. Must be 'T' followed by an integer.",
              "marker_information": {
                // For QUESTION: The start of an inquiry by a parliamentarian. Often these are phrased as questions, but not always. For example, 'Tell me more about the budget' is an inquiry about the budget.
                "question": "text of the question",
                "answer": "the answer if available",
                "who_is_asking": "speaker name",
                "who_is_being_asked": "target speaker"

                // For TESTIMONY: The start of testimony by a meeting attendee who is not a parliamentarian. Often there is an agency that testifies.
                "speaker_name": "name",
                "speaker_role": "role",
                "speaker_organization": "org",
                "testimony_title": "title"

                // For OPENING_STATEMENT: Opening statements by a parliamentarian. These are standalone statements or addresses by a parliamentarian opening a committee hearing.
                "speaker_name": "name",
                "opening_statement_title": "title"

                // For PROCEDURE: The start of a procedural portion of the meeting, for example the start of a meeting, a vote, a roll call, calling up testimony, etc. The start of the meeting, where parliamentarians ask people to silence their phones, should always be called "Front Matter".
                "procedure_title": "title"
              }
            }
          ]
        }

        Analyze the following transcript segments and identify any markers:
        """
      },
      %{
        role: "user",
        content: content
      }
    ]
  end

  defp format_segments_for_llm(segments) do
    segments
    |> Enum.map_join("\n\n", fn segment ->
      speaker = Map.get(segment, "speaker")
      text = Map.get(segment, "text")
      sentence_number = Map.get(segment, "sentence_number")

      "[#{speaker}]\n[#{sentence_number}] #{text}"
    end)
  end

  defp parse_llm_response(%{"choices" => [%{"message" => %{"content" => content}}]}) do
    require Logger

    case Jason.decode(content) do
      {:ok, decoded} ->
        Logger.info("Decoded JSON: #{inspect(decoded, pretty: true)}")

        case decoded do
          %{"transcript_markers" => markers} when is_list(markers) ->
            Logger.info("Found #{length(markers)} markers in response")
            parsed_markers = Enum.map(markers, &convert_to_marker_struct/1)
            {:ok, parsed_markers}

          other ->
            Logger.error("Unexpected JSON structure: #{inspect(other, pretty: true)}")
            {:error, "Invalid response format - expected transcript_markers array"}
        end

      {:error, error} ->
        Logger.error("JSON parsing failed: #{inspect(error)}")
        {:error, "JSON parsing failed: #{inspect(error)}"}
    end
  end

  defp parse_llm_response(other) do
    require Logger
    Logger.error("Unexpected response structure: #{inspect(other, pretty: true)}")
    {:error, "Unexpected response format"}
  end

  defp convert_to_marker_struct(%{
         "marker_type" => type,
         "sentence_number" => sentence_number,
         "marker_information" => info
       }) do
    marker_type = String.downcase(type) |> String.to_existing_atom()
    marker_info = convert_marker_info(marker_type, info)

    %TranscriptMarker{
      marker_type: marker_type,
      sentence_number: sentence_number,
      marker_information: marker_info
    }
  end

  defp convert_marker_info(:question, info) do
    struct(Question, %{
      question: info["question"],
      answer: info["answer"],
      who_is_asking: info["who_is_asking"],
      who_is_being_asked: info["who_is_being_asked"]
    })
  end

  defp convert_marker_info(:testimony, info) do
    struct(Testimony, %{
      speaker_name: info["speaker_name"],
      speaker_role: info["speaker_role"],
      speaker_organization: info["speaker_organization"],
      testimony_title: info["testimony_title"]
    })
  end

  defp convert_marker_info(:opening_statement, info) do
    struct(OpeningStatement, %{
      speaker_name: info["speaker_name"],
      opening_statement_title: info["opening_statement_title"]
    })
  end

  defp convert_marker_info(:procedure, info) do
    struct(Procedure, %{
      procedure_title: info["procedure_title"]
    })
  end
end
