defmodule CivicusWeb.Inquiries do
  use CivicusWeb, :live_view

  alias Civicus.Inquiries
  alias CivicusWeb.Components.{HeaderNav, VideoPlayer, TranscriptView}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_time, 0)
     |> assign(:transcribing?, false)
     |> assign(:progress, nil)
     |> assign(:inquiries, list_inquiries())
     |> assign(:selected_inquiry, nil)}
  end

  @impl true
  def handle_event("seek_video", %{"time" => time}, socket) do
    {time_ms, _} = Integer.parse(time)
    time_seconds = div(time_ms, 1000)

    {:noreply,
     socket
     |> push_event("seek_video", %{time: time_seconds})}
  end

  @impl true
  def handle_info({:seek_video, time}, socket) do
    time_ms =
      case Integer.parse(time) do
        {val, _} -> val
        :error -> 0
      end

    {:noreply,
     socket
     |> assign(:current_time, time_ms)
     |> push_event("seek_video", %{time: div(time_ms, 1000)})}
  end

  @impl true
  def handle_event("select_inquiry", %{"id" => id}, socket) do
    inquiry = Inquiries.get_inquiry!(id)
    {:noreply, assign(socket, selected_inquiry: inquiry)}
  end

  defp list_inquiries do
    Inquiries.list_inquiries()
  end
end
