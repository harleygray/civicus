defmodule Civicus.Workers.MemberUpdater do
  use Oban.Worker, queue: :member_updates
  require Logger
  alias Civicus.Parliament.Members

  @senate_csv_url "https://www.aph.gov.au/-/media/03_Senators_and_Members/Address_Labels_and_CSV_files/Senators/allsenph.csv"
  @reps_csv_url "https://www.aph.gov.au/-/media/03_Senators_and_Members/Address_Labels_and_CSV_files/FamilynameRepsCSV.csv"

  @impl Oban.Worker
  def perform(_job) do
    with :ok <- update_senate_members(),
         :ok <- update_reps_members() do
      :ok
    end
  end

  defp update_senate_members do
    case download_csv(@senate_csv_url) do
      {:ok, body} ->
        process_senate_csv(body)
        :ok

      error ->
        Logger.error("Failed to download Senate CSV: #{inspect(error)}")
        error
    end
  end

  defp update_reps_members do
    case download_csv(@reps_csv_url) do
      {:ok, body} ->
        process_reps_csv(body)
        :ok

      error ->
        Logger.error("Failed to download Reps CSV: #{inspect(error)}")
        error
    end
  end

  defp download_csv(url) do
    case HTTPoison.get(url) do
      {:ok, %{status_code: 200, body: body}} -> {:ok, body}
      {:ok, response} -> {:error, "Unexpected response: #{inspect(response)}"}
      error -> error
    end
  end

  defp process_senate_csv(csv_content) do
    csv_content
    |> parse_csv()
    |> Enum.drop(1)
    |> Enum.each(fn row ->
      member_attrs = %{
        title: Enum.at(row, 0),
        salutation: Enum.at(row, 1),
        surname: Enum.at(row, 2),
        first_name: Enum.at(row, 3),
        other_name: Enum.at(row, 4),
        preferred_name: Enum.at(row, 5),
        initials: Enum.at(row, 6),
        post_nominals: Enum.at(row, 7),
        state: Enum.at(row, 8),
        party: Enum.at(row, 9),
        chamber: "Senate",
        aph_id: generate_senator_id(row)
      }

      case Members.get_member_by_aph_id(member_attrs.aph_id) do
        nil ->
          Members.create_member(member_attrs)

          Logger.info(
            "Created new Senate member: #{member_attrs.first_name} #{member_attrs.surname}"
          )

        existing_member ->
          if member_details_changed?(existing_member, member_attrs) do
            Members.update_member(existing_member, member_attrs)

            Logger.info(
              "Updated Senate member: #{member_attrs.first_name} #{member_attrs.surname}"
            )
          end
      end
    end)
  end

  defp process_reps_csv(csv_content) do
    csv_content
    |> parse_csv()
    |> Enum.drop(1)
    |> Enum.each(fn row ->
      member_attrs = %{
        title: Enum.at(row, 0),
        salutation: Enum.at(row, 1),
        surname: Enum.at(row, 3),
        first_name: Enum.at(row, 4),
        other_name: Enum.at(row, 5),
        preferred_name: Enum.at(row, 6),
        initials: Enum.at(row, 7),
        post_nominals: Enum.at(row, 2),
        state: Enum.at(row, 9),
        party: Enum.at(row, 10),
        electorate: Enum.at(row, 8),
        chamber: "House of Representatives",
        aph_id: generate_reps_id(row)
      }

      case Members.get_member_by_aph_id(member_attrs.aph_id) do
        nil ->
          Members.create_member(member_attrs)

          Logger.info(
            "Created new Representative: #{member_attrs.first_name} #{member_attrs.surname}"
          )

        existing_member ->
          if member_details_changed?(existing_member, member_attrs) do
            Members.update_member(existing_member, member_attrs)

            Logger.info(
              "Updated Representative: #{member_attrs.first_name} #{member_attrs.surname}"
            )
          end
      end
    end)
  end

  defp parse_csv(content) do
    content
    |> String.split("\r\n")
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&parse_csv_line/1)
  end

  defp parse_csv_line(line) do
    line
    |> String.split(",")
    |> Enum.map(fn field ->
      field
      |> String.trim()
      |> remove_quotes()
    end)
  end

  defp remove_quotes(field) do
    field
    |> String.replace(~r/^"/, "")
    |> String.replace(~r/"$/, "")
  end

  defp generate_aph_id(row) do
    # Create a unique identifier based on available data
    # This is a simplified example - you might want to use actual IDs from the CSV if available
    data = Enum.join(row, "-")
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end

  # Generate a consistent ID for senators using their unique attributes
  defp generate_senator_id(row) do
    # Combine surname, first name, and state for a unique identifier
    identifier =
      [
        # Surname
        Enum.at(row, 2),
        # First Name
        Enum.at(row, 3),
        # State
        Enum.at(row, 8),
        "Senate"
      ]
      |> Enum.join("-")
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9-]/, "")

    "sen-" <> identifier
  end

  # Update the generate_reps_id function to use relevant fields
  defp generate_reps_id(row) do
    # Combine surname, first name, and electorate for a unique identifier
    identifier =
      [
        # Surname
        Enum.at(row, 3),
        # First Name
        Enum.at(row, 4),
        # Electorate
        Enum.at(row, 8),
        "HoR"
      ]
      |> Enum.join("-")
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9-]/, "")

    "rep-" <> identifier
  end

  # Helper function to check if member details have changed
  defp member_details_changed?(existing, new) do
    fields_to_compare = [
      :title,
      :salutation,
      :surname,
      :first_name,
      :other_name,
      :preferred_name,
      :initials,
      :post_nominals,
      :state,
      :party,
      :electorate,
      :chamber
    ]

    Enum.any?(fields_to_compare, fn field ->
      Map.get(existing, field) != Map.get(new, field)
    end)
  end
end
