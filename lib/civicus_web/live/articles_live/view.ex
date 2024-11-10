defmodule CivicusWeb.Articles.View do
  use CivicusWeb, :live_view
  alias CivicusWeb.Components.HeaderNav, as: HeaderNav
  alias Civicus.Content

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _uri, socket) do
    case Content.get_article(slug) do
      nil ->
        {:noreply,
         socket |> put_flash(:error, "Article not found") |> push_navigate(to: ~p"/articles")}

      article ->
        {:noreply,
         socket
         |> assign(article: article, page_title: article.title)
         |> assign_navigation(article)}
    end
  end

  @impl true
  def handle_event("navigate", %{"to" => "prev"}, socket) do
    {:noreply, navigate_to_article(socket, socket.assigns.prev_article_slug)}
  end

  def handle_event("navigate", %{"to" => "next"}, socket) do
    {:noreply, navigate_to_article(socket, socket.assigns.next_article_slug)}
  end

  defp assign_navigation(socket, current_article) do
    articles = Content.list_articles()
    current_index = Enum.find_index(articles, &(&1.id == current_article.id))

    prev_article = Enum.at(articles, current_index - 1)
    next_article = Enum.at(articles, current_index + 1)

    socket
    |> assign(:prev_article_slug, prev_article && prev_article.slug)
    |> assign(:next_article_slug, next_article && next_article.slug)
  end

  defp navigate_to_article(socket, nil), do: socket

  defp navigate_to_article(socket, slug) do
    socket
    |> push_patch(to: ~p"/articles/#{slug}")
  end

  def render_markdown(content) do
    options = %Earmark.Options{
      code_class_prefix: "language-",
      smartypants: false
    }

    {:safe, Earmark.as_html!(content, options)}
  end
end
