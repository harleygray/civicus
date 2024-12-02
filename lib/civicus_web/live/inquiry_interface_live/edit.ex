defmodule CivicusWeb.InquiryInterface.Edit do
  use CivicusWeb, :live_view

  alias Civicus.Inquiries
  alias Civicus.Inquiries.Inquiry
  alias CivicusWeb.Components.HeaderNav
  alias Phoenix.PubSub

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    if inquiry = Inquiries.get_inquiry!(slug) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Civicus.PubSub, "transcription:#{inquiry.id}")
        Phoenix.PubSub.subscribe(Civicus.PubSub, "transcription_progress:#{inquiry.id}")
      end

      {:ok,
       socket
       |> assign(:page_title, inquiry.name)
       |> assign(:inquiry, inquiry)
       |> assign(:progress, nil)
       |> assign(:transcribing?, false)
       |> assign(:form, to_form(Inquiries.change_inquiry(inquiry)))}
    else
      {:ok,
       socket
       |> put_flash(:error, "Inquiry not found")
       |> redirect(to: ~p"/inquiries")}
    end
  end

  @impl true
  def handle_event("validate", %{"inquiry" => params}, socket) do
    form =
      socket.assigns.inquiry
      |> Inquiries.change_inquiry(params)
      |> to_form(as: "inquiry")

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"inquiry" => params}, socket) do
    save_inquiry(socket, socket.assigns.inquiry, params)
  end

  def handle_event("transcribe", _, socket) do
    case Inquiries.start_transcription(socket.assigns.inquiry) do
      {:ok, _inquiry} ->
        {:noreply,
         socket
         |> assign(:transcribing?, true)
         |> put_flash(:info, "Transcription started")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to start transcription: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:transcription_started, _inquiry_id}, socket) do
    {:noreply,
     socket
     |> assign(:transcribing?, true)
     |> put_flash(:info, "Transcription started")}
  end

  @impl true
  def handle_info({:transcription_progress, message}, socket) do
    {:noreply, assign(socket, :progress, message)}
  end

  @impl true
  def handle_info({:transcription_complete, transcript}, socket) do
    {:noreply,
     socket
     |> assign(:transcribing?, false)
     |> assign(:progress, nil)
     |> assign(:inquiry, %{socket.assigns.inquiry | transcript: transcript})
     |> put_flash(:info, "Transcription completed")}
  end

  @impl true
  def handle_info({:transcription_error, error}, socket) do
    {:noreply,
     socket
     |> assign(:transcribing?, false)
     |> assign(:progress, nil)
     |> put_flash(:error, "Transcription failed: #{error}")}
  end

  defp save_inquiry(socket, %Inquiry{id: nil}, params) do
    case Inquiries.create_inquiry(params) do
      {:ok, inquiry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Inquiry created successfully")
         |> push_navigate(to: ~p"/inquiry_interface/#{inquiry.slug || inquiry.id}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_inquiry(socket, inquiry, params) do
    case Inquiries.update_inquiry(inquiry, params) do
      {:ok, inquiry} ->
        {:noreply,
         socket
         |> put_flash(:info, "Inquiry updated successfully")
         |> push_navigate(to: ~p"/inquiry_interface/#{inquiry.slug || inquiry.id}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: "inquiry"))
  end
end
