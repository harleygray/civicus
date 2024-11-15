defmodule Civicus.Repo.Migrations.AddStatusToArticles do
  use Ecto.Migration

  def change do
    create_query = "CREATE TYPE article_status AS ENUM ('wip', 'published')"
    drop_query = "DROP TYPE article_status"

    execute(create_query, drop_query)

    alter table(:articles) do
      add :status, :article_status, null: false, default: "wip"
    end
  end
end
