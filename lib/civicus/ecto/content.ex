defmodule Civicus.Content do
  import Ecto.Query, warn: false
  alias Civicus.Repo
  alias Civicus.Content.Article

  def list_articles(order \\ :asc) do
    Repo.all(from a in Article, order_by: [{^order, coalesce(a.published_at, a.inserted_at)}])
  end

  def get_article(id) when is_integer(id) do
    Repo.get(Article, id)
  end

  def get_article(slug) when is_binary(slug) do
    Repo.get_by(Article, slug: slug)
  end

  def create_article(attrs \\ %{}) do
    %Article{}
    |> Article.changeset(attrs)
    |> Repo.insert()
  end

  def update_article(%Article{} = article, attrs) do
    article
    |> Article.changeset(attrs)
    |> Repo.update()
  end

  def change_article(%Article{} = article, attrs \\ %{}) do
    Article.changeset(article, attrs)
  end

  @doc """
  Returns a list of articles filtered by status.
  """
  def list_articles_by_status(status) when status in [:wip, :published] do
    Repo.all(from a in Article, where: a.status == ^status)
  end

  @doc """
  Returns a list of published articles, ordered by published_at date.
  Useful for public-facing pages.
  """
  def list_published_articles do
    Repo.all(
      from a in Article,
        where: a.status == :published,
        order_by: [desc: a.published_at]
    )
  end

  @doc """
  Publishes an article by updating its status and setting published_at date.
  """
  def publish_article(%Article{} = article) do
    now = Date.utc_today()

    article
    |> Article.changeset(%{status: :published, published_at: now})
    |> Repo.update()
  end

  @doc """
  Unpublishes an article by setting status back to WIP.
  """
  def unpublish_article(%Article{} = article) do
    article
    |> Article.changeset(%{status: :wip, published_at: nil})
    |> Repo.update()
  end
end
