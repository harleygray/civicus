defmodule Civicus.Content.Article do
  use Ecto.Schema
  import Ecto.Changeset

  schema "articles" do
    field :title, :string
    field :slug, :string
    field :content, :string
    field :excerpt, :string
    field :published_at, :date

    timestamps()
  end

  def changeset(article, attrs) do
    article
    |> cast(attrs, [:title, :slug, :content, :excerpt, :published_at])
    |> validate_required([:title, :slug, :content])
    |> unique_constraint(:slug)
  end
end
