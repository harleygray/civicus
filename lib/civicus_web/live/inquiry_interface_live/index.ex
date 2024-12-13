defmodule CivicusWeb.InquiryInterface.Index do
  use CivicusWeb, :live_view
  alias CivicusWeb.Components.HeaderNav
  alias Civicus.Inquiries
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Senate Inquiries",
       inquiries: list_inquiries()
     )}
  end

  @impl true
  def handle_event("delete_inquiry", %{"id" => id}, socket) do
    inquiry = Inquiries.get_inquiry!(id)
    {:ok, _} = Inquiries.delete_inquiry(inquiry)

    {:noreply,
     socket
     |> put_flash(:info, "Inquiry deleted successfully")
     |> assign(:inquiries, list_inquiries())}
  end

  @impl true
  def handle_event("clear_oban_jobs", _params, socket) do
    # Cancel all jobs in all queues
    queues = [:media_processing, :member_updates]

    results =
      for queue <- queues do
        case Oban.drain_queue(queue: queue) do
          %{cancelled: cancelled} = result ->
            Logger.info("Queue #{queue} stats: #{inspect(result)}")
            cancelled

          error ->
            Logger.error("Failed to clear queue #{queue}: #{inspect(error)}")
            0
        end
      end

    total_cancelled = Enum.sum(results)

    {:noreply,
     socket
     |> put_flash(:info, "Cleared #{total_cancelled} jobs from queues")}
  end

  defp list_inquiries do
    Inquiries.list_inquiries()
  end
end
