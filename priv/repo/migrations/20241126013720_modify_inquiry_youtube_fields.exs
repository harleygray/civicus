defmodule Civicus.Repo.Migrations.ModifyInquiryYoutubeFields do
  use Ecto.Migration

  def change do
    rename table(:inquiries), :youtube_id, to: :youtube_url

    alter table(:inquiries) do
      add :youtube_embed, :string
    end

    drop_if_exists index(:inquiries, [:youtube_id])
    create unique_index(:inquiries, [:youtube_url])
  end
end
