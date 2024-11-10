defmodule Civicus.DatabaseHelpers do
  def list_tables do
    Ecto.Adapters.SQL.query!(
      Civicus.Repo,
      "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'"
    )
    |> Map.get(:rows)
    |> List.flatten()
  end
end
