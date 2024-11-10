defmodule Civicus.Repo do
  use Ecto.Repo,
    otp_app: :civicus,
    adapter: Ecto.Adapters.Postgres

  def init(_type, config) do
    masked_config =
      Enum.map(config, fn
        {:url, url} -> {:url, mask_url(url)}
        other -> other
      end)

    IO.puts("Repo config: #{inspect(masked_config)}")
    {:ok, config}
  end

  defp mask_url(url) do
    uri = URI.parse(url)
    masked_uri = %{uri | userinfo: "#{uri.userinfo |> String.split(":") |> hd}:****"}
    URI.to_string(masked_uri)
  end
end
