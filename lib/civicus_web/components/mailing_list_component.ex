defmodule CivicusWeb.Components.MailingListComponent do
  use CivicusWeb, :live_component
  alias Civicus.Newsletter
  alias Civicus.Newsletter.Subscriber

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mailing-list-component">
      <h2>Co-create the future of journalism</h2>
      <p class="cta-text">
        Get news and tools designed for engaged, knowledge-seeking citizens. <br />
        Join the mailing list for updates and early access.
      </p>
      <.form
        for={@form}
        id="newsletter-form"
        phx-target={@myself}
        phx-submit="save"
        class="newsletter-form"
      >
        <.input
          field={@form[:email]}
          type="email"
          required
          placeholder="Email address"
          class="input-email"
        />

        <.button type="submit" class="submit-button" phx-disable-with="Subscribing...">
          Subscribe
        </.button>
      </.form>
      <p class={@message_class}><%= @message %></p>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    changeset = Newsletter.change_subscriber(%Subscriber{})
    {:ok, assign(socket, form: to_form(changeset), message: nil, message_class: "")}
  end

  @impl true
  def handle_event("save", %{"subscriber" => subscriber_params}, socket) do
    sanitised_params = Map.update(subscriber_params, "email", "", &HtmlSanitizeEx.strip_tags/1)

    IO.inspect(sanitised_params, label: "sanitised_params")

    case Newsletter.create_subscriber(sanitised_params) do
      {:ok, _subscriber} ->
        {:noreply,
         socket
         |> assign(
           message: "✅ Successfully subscribed!",
           message_class: "text-blue-600",
           form: to_form(Newsletter.change_subscriber(%Subscriber{}))
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {message, message_class} = get_error_message(changeset)

        {:noreply,
         socket
         |> assign(
           form: to_form(changeset),
           message: message,
           message_class: message_class
         )}
    end
  end

  defp get_error_message(changeset) do
    cond do
      changeset.errors[:email] ->
        {msg, _} = changeset.errors[:email]
        IO.puts("msg: #{msg}")

        if msg == "Already subscribed" do
          {"✅ Already subscribed", "text-blue-600"}
        else
          {"❌ #{msg}", "text-red-600"}
        end

      true ->
        {"❌ An error occurred. Please try again.", "text-red-600"}
    end
  end
end
