defmodule CivicusWeb.Components.Footer do
  use Phoenix.Component

  def footer(assigns) do
    ~H"""
    <footer class="footer-container">
      <div class="footer-inner">
        <div class="footer-social-icons">
          <a href="https://x.com/harleyraygray/" target="blank" class="social-link">
            <img src="/images/svg/x.svg" alt="X (Twitter)" class="social-icon" />
          </a>
          <a href="https://www.linkedin.com/in/harleygray1996/" target="blank" class="social-link">
            <img src="/images/svg/linkedin.svg" alt="LinkedIn" class="social-icon" />
          </a>
        </div>
      </div>
    </footer>
    """
  end
end
