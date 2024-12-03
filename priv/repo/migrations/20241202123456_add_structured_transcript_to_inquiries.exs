defmodule Civicus.Repo.Migrations.AddStructuredTranscriptToInquiries do
  use Ecto.Migration

  def change do
    alter table(:inquiries) do
      add :structured_transcript, :jsonb
    end
  end
end
