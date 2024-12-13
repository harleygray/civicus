defmodule Civicus.Workers.CleanupWorker do
  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    audio_dir = "priv/static/audio"
    # Delete files older than 24 hours
    threshold = DateTime.add(DateTime.utc_now(), -24, :hour)

    case File.ls(audio_dir) do
      {:ok, files} ->
        Enum.each(files, fn file ->
          path = Path.join(audio_dir, file)

          case File.stat(path) do
            {:ok, %File.Stat{mtime: mtime}} ->
              if DateTime.compare(DateTime.from_unix!(mtime), threshold) == :lt do
                File.rm(path)
                Logger.info("[CleanupWorker] Deleted old audio file: #{path}")
              end

            {:error, reason} ->
              Logger.error("[CleanupWorker] Failed to stat file #{path}: #{inspect(reason)}")
          end
        end)

        :ok

      {:error, reason} ->
        Logger.error("[CleanupWorker] Failed to list audio directory: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
