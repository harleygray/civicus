defmodule Civicus.Repo.Migrations.CreateArticles do
  use Ecto.Migration

  def change do
    create table(:articles) do
      add :title, :string, null: false
      add :slug, :string, null: false
      add :content, :text
      add :excerpt, :text
      add :published_at, :utc_datetime

      timestamps()
    end

    create unique_index(:articles, [:slug])
  end
end
