defmodule Civicus.Inquiries.SpeakerMapping do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :speaker_id, :string
    field :name, :string
  end

  def changeset(speaker_mapping, attrs) do
    speaker_mapping
    |> cast(attrs, [:speaker_id, :name])
    |> validate_required([:speaker_id, :name])
    |> validate_format(:speaker_id, ~r/^Speaker \d+$/,
      message: "must be in format 'Speaker X' where X is a number"
    )
  end
end
