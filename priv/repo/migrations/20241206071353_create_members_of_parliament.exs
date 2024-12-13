defmodule Civicus.Repo.Migrations.CreateMembers do
  use Ecto.Migration

  def change do
    create table(:members) do
      add :title, :string
      add :salutation, :string
      add :surname, :string
      add :first_name, :string
      add :other_name, :string
      add :preferred_name, :string
      add :initials, :string
      add :post_nominals, :string
      add :chamber, :string
      add :state, :string
      add :electorate, :string
      add :party, :string
      add :email, :string
      add :aph_id, :string
      add :parliament_number, :integer

      timestamps()
    end

    create unique_index(:members, [:aph_id])
  end
end
