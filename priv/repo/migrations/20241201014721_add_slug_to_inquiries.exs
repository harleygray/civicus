defmodule Civicus.Repo.Migrations.AddSlugToInquiries do
  use Ecto.Migration

  def change do
    alter table(:inquiries) do
      add :slug, :string
    end

    create unique_index(:inquiries, [:slug])
  end
end
