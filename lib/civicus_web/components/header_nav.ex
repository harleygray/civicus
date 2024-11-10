defmodule CivicusWeb.Components.HeaderNav do
  use Phoenix.LiveComponent

  @impl true
  @spec render(any()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <nav id="header" class="header-nav">
      <div class="header-content">
        <a id="nav-civicus" class="logo-link" href="#">
          CIVICUS
        </a>

        <div class="nav-links md:flex">
          <.link navigate="/" class="nav-link">Home</.link>
          <.link navigate="/articles" class="nav-link">Articles</.link>
        </div>
      </div>
    </nav>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, socket}
  end
end
