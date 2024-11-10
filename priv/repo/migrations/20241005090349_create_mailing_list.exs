defmodule Civicus.Repo.Migrations.CreateMailingList do
  use Ecto.Migration

  def change do
    create table(:newsletter_subscribers) do
      add :email, :string, null: false

      timestamps()
    end

    create unique_index(:newsletter_subscribers, [:email])
  end
end
