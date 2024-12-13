defmodule Civicus.Repo.Migrations.AddSpeakerMappingsToInquiries do
  use Ecto.Migration

  def change do
    alter table(:inquiries) do
      add :speaker_mappings, :map, default: %{}
    end
  end
end
