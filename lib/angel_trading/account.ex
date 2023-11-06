defmodule AngelTrading.Account do
  use Tesla

  plug Tesla.Middleware.BaseUrl, Application.get_env(:angel_trading, :firebase_api, "")

  plug Tesla.Middleware.Headers, []
  plug Tesla.Middleware.Query, auth: Application.get_env(:angel_trading, :firebase_token, "")
  plug Tesla.Middleware.JSON

  alias AngelTrading.Utils

  def get_client(client_code) do
    get("/clients/#{client_code}.json")
  end

  def get_client_codes(name) do
    get("/users/#{name}/clients.json")
  end

  def set_tokens(name, %{
        "client_code" => client_code,
        "token" => token,
        "refresh_token" => refresh_token,
        "feed_token" => feed_token
      }) do
    with {:ok, _} <- patch("/users/#{name}/clients.json", %{client_code => client_code}),
         {:ok, _} <-
           patch(
             "clients.json",
             %{
               client_code =>
                 Utils.encrypt(:client_tokens, %{
                   "client_code" => client_code,
                   "token" => token,
                   "refresh_token" => refresh_token,
                   "feed_token" => feed_token
                 })
             }
           ) do
      :ok
    else
      _ -> :error
    end
  end
end
