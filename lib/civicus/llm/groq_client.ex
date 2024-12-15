defmodule Civicus.LLM.GroqClient do
  @moduledoc """
  Client for interacting with Groq's LLM API.
  """

  @base_url "https://api.groq.com/openai/v1"
  @model "llama3-8b-8192"

  def chat_completion(messages, opts \\ []) do
    url = @base_url <> "/chat/completions"
    api_key = Application.get_env(:civicus, :groq_api_key)

    headers = [
      {"Authorization", "Bearer #{api_key}"},
      {"Content-Type", "application/json"}
    ]

    body =
      Jason.encode!(%{
        model: @model,
        messages: messages,
        response_format: %{type: "json_object"},
        temperature: Keyword.get(opts, :temperature, 0.2)
      })

    case HTTPoison.post(url, body, headers) do
      {:ok, %{status_code: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %{status_code: status_code, body: body}} ->
        {:error, "Groq API error: #{status_code} - #{body}"}

      {:error, error} ->
        {:error, "HTTP request failed: #{inspect(error)}"}
    end
  end
end
