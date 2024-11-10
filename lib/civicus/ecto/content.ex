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
end
