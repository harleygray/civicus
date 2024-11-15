defmodule Civicus.Repo.Migrations.UpdateArticlesPublishedAtToDate do
  use Ecto.Migration

  def up do
    alter table(:articles) do
      modify :published_at, :date
    end
  end

  def down do
    alter table(:articles) do
      modify :published_at, :utc_datetime
    end
  end
end
