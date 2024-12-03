defmodule Civicus.Inquiries.Inquiry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "inquiries" do
    field :youtube_url, :string
    field :youtube_embed, :string
    field :name, :string
    field :transcript, :string
    field :structured_transcript, :map
    field :senators, {:array, :string}
    field :committee, :string
    field :date_held, :date
    field :status, :string, default: "pending"
    field :slug, :string

    timestamps()
  end

  def changeset(inquiry, attrs) do
    inquiry
    |> cast(attrs, [
      :youtube_url,
      :youtube_embed,
      :name,
      :transcript,
      :structured_transcript,
      :senators,
      :committee,
      :date_held,
      :status,
      :slug
    ])
    |> validate_required([:youtube_url, :youtube_embed, :name])
    |> maybe_generate_slug()
    |> unique_constraint(:youtube_url)
    |> unique_constraint(:slug)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
      message: "must contain only lowercase letters, numbers, and hyphens"
    )
  end

  defp maybe_generate_slug(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        case get_change(changeset, :name) do
          nil -> changeset
          name -> put_change(changeset, :slug, generate_slug(name))
        end

      _ ->
        changeset
    end
  end

  defp generate_slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end
end
