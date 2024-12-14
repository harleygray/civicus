defmodule Civicus.Repo.Migrations.AddChaptersToInquiries do
  use Ecto.Migration

  def change do
    alter table(:inquiries) do
      add :chapters, :map, default: "{}"
    end
  end
end
