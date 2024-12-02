defmodule Civicus.Repo.Migrations.CreateInquiries do
  use Ecto.Migration

  def change do
    create table(:inquiries) do
      add :youtube_id, :string, null: false
      add :name, :string, null: false
      add :transcript, :text
      add :senators, {:array, :string}
      add :committee, :string
      add :date_held, :date
      add :status, :string

      timestamps()
    end

    create unique_index(:inquiries, [:youtube_id])
  end
end
