defmodule Civicus.Inquiries do
  @moduledoc """
  The Inquiries context.
  This module handles all business logic related to Senate Inquiries.
  """

  require Logger
  alias Civicus.Repo
  alias Civicus.Inquiries.Inquiry
  alias Civicus.Workers.YoutubeProcessor

  @doc """
  Returns the list of inquiries.
  """
  @spec list_inquiries() :: [Inquiry.t()]
  def list_inquiries do
    Repo.all(Inquiry)
  end

  @doc """
  Gets a single inquiry by ID.
  Raises `Ecto.NoResultsError` if the Inquiry does not exist.
  """
  def get_inquiry!(slug_or_id) when is_binary(slug_or_id) do
    case Integer.parse(slug_or_id) do
      {id, ""} ->
        # If it's a valid integer string, query by id
        Repo.get!(Inquiry, id)

      _ ->
        # Otherwise query by slug
        Repo.get_by!(Inquiry, slug: slug_or_id)
    end
  end

  def get_inquiry!(id) when is_integer(id) do
    Repo.get!(Inquiry, id)
  end

  @doc """
  Returns a changeset for an inquiry.
  Takes an existing inquiry struct and a map of attributes.
  Used to validate and prepare changes to an inquiry.
  """
  @spec change_inquiry(Inquiry.t(), map()) :: Ecto.Changeset.t()
  def change_inquiry(%Inquiry{} = inquiry, attrs \\ %{}) do
    Inquiry.changeset(inquiry, attrs)
  end

  @doc """
  Gets a single inquiry by YouTube URL.
  Raises `Ecto.NoResultsError` if the Inquiry does not exist.
  """
  def get_inquiry_by_youtube_url!(youtube_url) do
    Repo.get_by!(Inquiry, youtube_url: youtube_url)
  end

  @doc """
  Creates a inquiry.
  """
  def create_inquiry(attrs \\ %{}) do
    %Inquiry{}
    |> Inquiry.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a inquiry.
  """
  def update_inquiry(%Inquiry{} = inquiry, attrs) do
    inquiry
    |> Inquiry.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Starts the transcription process for an inquiry.
  Updates the status to "work_in_progress" and enqueues an Oban job.
  """
  def start_transcription(%Inquiry{} = inquiry) do
    Logger.info("Starting transcription for inquiry #{inquiry.id}")

    with {:ok, updated_inquiry} <- update_inquiry(inquiry, %{status: "processing"}),
         {:ok, %Oban.Job{} = job} <-
           %{inquiry_id: updated_inquiry.id}
           |> Civicus.Workers.YoutubeProcessor.new()
           |> Oban.insert() do
      Logger.info("Successfully enqueued transcription job #{job.id} for inquiry #{inquiry.id}")
      broadcast_transcription_started(inquiry.id)
      {:ok, updated_inquiry}
    else
      {:error, error} ->
        Logger.error("Failed to start transcription: #{inspect(error)}")
        _ = update_inquiry(inquiry, %{status: "failed"})
        {:error, error}
    end
  end

  defp broadcast_transcription_started(inquiry_id) do
    Phoenix.PubSub.broadcast(
      Civicus.PubSub,
      "transcription:#{inquiry_id}",
      {:transcription_started, inquiry_id}
    )
  end

  @doc """
  Gets a single inquiry by slug.
  Returns nil if no inquiry is found.
  """
  def get_inquiry_by_slug(slug) when is_binary(slug) do
    Repo.get_by(Inquiry, slug: slug)
  end

  @doc """
  Gets a single inquiry by slug.
  Raises `Ecto.NoResultsError` if no inquiry is found.
  """
  def get_inquiry_by_slug!(slug) when is_binary(slug) do
    Repo.get_by!(Inquiry, slug: slug)
  end

  def get_inquiry_by_youtube_url(youtube_url) do
    Repo.get_by(Inquiry, youtube_url: youtube_url)
  end
end
