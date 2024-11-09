defmodule Civicus.Repo do
  use Ecto.Repo,
    otp_app: :civicus,
    adapter: Ecto.Adapters.Postgres
end
