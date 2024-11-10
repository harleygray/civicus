defmodule CivicusWeb.Components.Hero do
  use Phoenix.Component

  def hero(assigns) do
    ~H"""
    <section class="hero">
      <img src="/images/svg/wave-background-2.svg" alt="Wave background" class="wave-background" />
      <div class="hero-content">
        <div class="hero-text">
          <h1 class="hero-title">Journalism for a strong Australia</h1>
        </div>
        <div class="hero-secondary">
          <blockquote>
            When We the People become one mass - breathing one breath and one spirit - Our might increases to a height of which it is difficult to find the limit.
          </blockquote>
        </div>
      </div>
    </section>
    """
  end
end
