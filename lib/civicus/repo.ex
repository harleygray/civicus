defmodule Civicus.Repo do
  use Ecto.Repo,
    otp_app: :civicus,
    adapter: Ecto.Adapters.Postgres

  def init(_type, config) do
    {:ok, config}
  end
end
