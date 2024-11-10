defmodule CivicusWeb.ArticleInterface do
  use CivicusWeb, :live_view
  alias CivicusWeb.UserAuth
  alias CivicusWeb.Components.HeaderNav, as: HeaderNav
  alias Civicus.Content
  alias Civicus.Content.Article

  @impl true
  def mount(_params, session, socket) do
    socket = assign_current_user(socket, session)

    {:ok,
     assign(socket,
       page_title: "Article Interface",
       page_specific_styles: "article_interface.css",
       articles: list_articles(),
       changeset: Content.change_article(%Article{}),
       show_form: false,
       editing_article: nil
     )}
  end

  @impl true
  def handle_event("new_article", _, socket) do
    {:noreply,
     assign(socket,
       show_form: true,
       changeset: Content.change_article(%Article{}),
       editing_article: nil
     )}
  end

  @impl true
  def handle_event("edit_article", %{"id" => id}, socket) do
    case Content.get_article(String.to_integer(id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Article not found")}

      article ->
        changeset = Content.change_article(article)

        {:noreply,
         assign(socket, changeset: changeset, editing_article: article, show_form: true)}
    end
  end

  @impl true
  def handle_event("save", %{"article" => article_params}, socket) do
    save_article(socket, socket.assigns.editing_article, article_params)
  end

  @impl true
  def handle_event("cancel", _, socket) do
    {:noreply, assign(socket, show_form: false, editing_article: nil)}
  end

  defp save_article(socket, nil, article_params) do
    case Content.create_article(article_params) do
      {:ok, _article} ->
        {:noreply,
         socket
         |> put_flash(:info, "Article created successfully")
         |> assign(:articles, list_articles())
         |> assign(:changeset, Content.change_article(%Article{}))
         |> assign(:show_form, false)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp save_article(socket, %Article{} = article, article_params) do
    case Content.update_article(article, article_params) do
      {:ok, _article} ->
        {:noreply,
         socket
         |> put_flash(:info, "Article updated successfully")
         |> assign(:articles, list_articles())
         |> assign(:changeset, Content.change_article(%Article{}))
         |> assign(:show_form, false)
         |> assign(:editing_article, nil)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp assign_current_user(socket, session) do
    assign_new(socket, :current_user, fn ->
      UserAuth.fetch_current_user(socket, session)
      |> Map.get(:assigns)
      |> Map.get(:current_user)
    end)
  end

  defp list_articles do
    Content.list_articles()
  end
end
