defmodule Civicus.Parliament.Member do
  use Ecto.Schema
  import Ecto.Changeset

  schema "members" do
    field :title, :string
    field :salutation, :string
    field :surname, :string
    field :first_name, :string
    field :other_name, :string
    field :preferred_name, :string
    field :initials, :string
    field :post_nominals, :string
    field :chamber, :string
    field :state, :string
    field :electorate, :string
    field :party, :string
    field :email, :string
    field :aph_id, :string
    field :parliament_number, :integer

    timestamps()
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [
      :title,
      :salutation,
      :surname,
      :first_name,
      :other_name,
      :preferred_name,
      :initials,
      :post_nominals,
      :chamber,
      :state,
      :electorate,
      :party,
      :email,
      :aph_id,
      :parliament_number
    ])
    |> validate_required([:surname, :chamber, :aph_id])
    |> unique_constraint(:aph_id)
  end
end
