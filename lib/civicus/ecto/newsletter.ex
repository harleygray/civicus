defmodule Civicus.Newsletter do
  @moduledoc """
  The Newsletter context.
  """

  import Ecto.Query, warn: false
  alias Civicus.Repo
  alias Civicus.Newsletter.Subscriber

  @doc """
  Creates a subscriber.
  """
  def create_subscriber(attrs \\ %{}) do
    %Subscriber{}
    |> Subscriber.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking subscriber changes.
  """
  def change_subscriber(%Subscriber{} = subscriber, attrs \\ %{}) do
    Subscriber.changeset(subscriber, attrs)
  end

  @doc """
  Returns the list of subscribers.
  """
  def list_subscribers do
    Repo.all(Subscriber)
  end
end
