defmodule CivicusWeb.Articles do
  use CivicusWeb, :live_view
  alias CivicusWeb.Components.HeaderNav, as: HeaderNav
  alias Civicus.Content

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :posts, list_articles())}
  end

  defp list_articles do
    Content.list_articles()
    |> Enum.map(fn article ->
      %{
        id: article.id,
        title: article.title,
        excerpt: article.excerpt || String.slice(article.content || "", 0, 100),
        slug: article.slug,
        published_at: article.published_at,
        status: article.status
      }
    end)
  end

  defp humanize_status(:wip), do: "Work in Progress"
  defp humanize_status(:published), do: "Published"
  defp humanize_status(_), do: "Unknown"
end
