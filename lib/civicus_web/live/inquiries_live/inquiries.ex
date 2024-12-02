defmodule CivicusWeb.Inquiries do
  use CivicusWeb, :live_view

  alias Civicus.Inquiries
  alias CivicusWeb.Components.HeaderNav, as: HeaderNav

  @impl true
  def mount(_params, _session, socket) do
    inquiries = Inquiries.list_inquiries()

    {:ok,
     socket
     |> assign(:current_page, "Inquiries")
     |> assign(:inquiries, inquiries)
     |> assign(:selected_inquiry, List.first(inquiries))}
  end

  @impl true
  def handle_event("select_inquiry", %{"id" => id}, socket) do
    inquiry = Inquiries.get_inquiry!(id)
    {:noreply, assign(socket, selected_inquiry: inquiry)}
  end
end
