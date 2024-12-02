defmodule Civicus.Repo.Migrations.ModifyTranscriptToText do
  use Ecto.Migration

  def change do
    alter table(:inquiries) do
      modify :transcript, :text, from: :string
    end
  end
end
