defmodule Civicus.Parliament.Members do
  import Ecto.Query
  alias Civicus.Repo
  alias Civicus.Parliament.Member

  def list_members do
    Repo.all(Member)
  end

  def get_member!(id), do: Repo.get!(Member, id)

  def create_member(attrs \\ %{}) do
    %Member{}
    |> Member.changeset(attrs)
    |> Repo.insert()
  end

  def update_member(%Member{} = member, attrs) do
    member
    |> Member.changeset(attrs)
    |> Repo.update()
  end

  def delete_member(%Member{} = member) do
    Repo.delete(member)
  end

  def get_member_by_aph_id(aph_id) do
    Repo.get_by(Member, aph_id: aph_id)
  end

  @doc """
  Searches for members by name, matching against first_name, surname, and preferred_name
  """
  def search_by_name(name_query) when byte_size(name_query) >= 2 do
    name_query = "%#{name_query}%"

    from(m in Member,
      where:
        ilike(m.surname, ^name_query) or
          ilike(m.first_name, ^name_query) or
          ilike(m.preferred_name, ^name_query),
      limit: 10
    )
    |> Repo.all()
  end

  def search_by_name(_), do: []
end
