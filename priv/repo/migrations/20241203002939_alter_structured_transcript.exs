defmodule Civicus.Repo.Migrations.AlterStructuredTranscript do
  use Ecto.Migration

  def change do
    alter table(:inquiries) do
      modify :structured_transcript, :map
    end
  end
end
