defmodule Civicus.Newsletter.Subscriber do
  use Ecto.Schema
  import Ecto.Changeset

  schema "newsletter_subscribers" do
    field :email, :string

    timestamps()
  end

  @doc false
  def changeset(subscriber, attrs) do
    subscriber
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email, message: "Already subscribed")
  end
end
