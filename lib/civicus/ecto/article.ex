defmodule Civicus.Content.Article do
  use Ecto.Schema
  import Ecto.Changeset

  @status_values [:wip, :published]

  schema "articles" do
    field :title, :string
    field :slug, :string
    field :content, :string
    field :excerpt, :string
    field :published_at, :date
    field :status, Ecto.Enum, values: @status_values, default: :wip

    timestamps()
  end

  def changeset(article, attrs) do
    article
    |> cast(attrs, [:title, :slug, :content, :excerpt, :published_at])
    |> validate_required([:title, :slug, :content])
    |> validate_inclusion(:status, @status_values)
    |> unique_constraint(:slug)
  end
end
