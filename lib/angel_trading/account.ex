defmodule AngelTrading.Account do
  use Tesla

  plug Tesla.Middleware.BaseUrl, Application.get_env(:angel_trading, :firebase_api, "")

  plug Tesla.Middleware.Headers, []
  plug Tesla.Middleware.Query, auth: Application.get_env(:angel_trading, :firebase_token, "")
  plug Tesla.Middleware.JSON

  require Logger

  alias AngelTrading.{Cache, Utils}

  def get_client(client_code) do
    Cache.get(
      "get_client_" <> client_code,
      {fn ->
         get("/clients/#{client_code}.json")
       end, []},
      :timer.hours(5)
    )
  end

  def get_client_codes(user_hash) do
    Cache.get(
      "get_client_codes_" <> user_hash,
      {fn ->
         get("/users/#{user_hash}/clients.json")
       end, []},
      :timer.hours(5)
    )
  end

  def get_user(user_hash) do
    Cache.get(
      "get_user_" <> user_hash,
      {fn ->
         get("/users/#{user_hash}.json")
       end, []},
      :timer.hours(5)
    )
  end

  def update_watchlist(user_hash, watchlist) do
    case patch("/users/#{user_hash}.json", %{watchlist: watchlist}) do
      {:ok, %{body: %{"watchlist" => _}}} ->
        Cache.del("get_user_" <> user_hash)
        :ok

      e ->
        Logger.error("[API][Watchlist] Error updating watchlist.")
        IO.inspect(e)
        :error
    end
  end

  def set_tokens(user_hash, %{
        "client_code" => client_code,
        "token" => token,
        "refresh_token" => refresh_token,
        "feed_token" => feed_token,
        "pin" => pin,
        "totp_secret" => totp_secret
      }) do
    with {:ok, %{body: %{^client_code => ^client_code}}} <-
           patch("/users/#{user_hash}/clients.json", %{client_code => client_code}),
         {:ok, %{body: %{^client_code => data}}} when is_bitstring(data) <-
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
      Cache.del("get_client_" <> client_code)
      Cache.del("get_user_" <> user_hash)
      Cache.del("get_client_codes_" <> user_hash)
      :ok
    else
      e ->
        Logger.error("[API][Tokens] Error saving tokens")
        IO.inspect(e)
        :error
    end
  end
end
