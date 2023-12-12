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

  def get_client_codes(user_hash) do
    get("/users/#{user_hash}/clients.json")
  end

  def get_user(user_hash), do: get("/users/#{user_hash}.json")

  def set_tokens(user_hash, %{
        "client_code" => client_code,
        "token" => token,
        "refresh_token" => refresh_token,
        "feed_token" => feed_token,
        "pin" => pin,
        "totp_secret" => totp_secret
      }) do
    with {:ok, _} <- patch("/users/#{user_hash}/clients.json", %{client_code => client_code}),
         {:ok, _} <-
           patch(
             "clients.json",
             %{
               client_code =>
                 Utils.encrypt(:client_tokens, %{
                   client_code: client_code,
                   token: token,
                   refresh_token: refresh_token,
                   feed_token: feed_token,
                   pin: pin,
                   totp_secret: totp_secret
                 })
             }
           ) do
      :ok
    else
      _ -> :error
    end
  end
end
