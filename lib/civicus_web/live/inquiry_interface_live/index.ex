defmodule CivicusWeb.InquiryInterface.Index do
  use CivicusWeb, :live_view
  alias CivicusWeb.Components.HeaderNav
  alias Civicus.Inquiries

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Senate Inquiries",
       inquiries: list_inquiries()
     )}
  end

  defp list_inquiries do
    Inquiries.list_inquiries()
  end
end
