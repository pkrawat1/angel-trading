defmodule AngelTrading.Account do
  use Tesla

  plug(Tesla.Middleware.BaseUrl, Application.get_env(:angel_trading, :firebase_api, ""))
  plug(Tesla.Middleware.Headers, [])
  plug(Tesla.Middleware.Query, auth: Application.get_env(:angel_trading, :firebase_token, ""))
  plug(Tesla.Middleware.JSON)

  require Logger

  alias AngelTrading.{Cache, Utils}

  @doc """
  Get client data from the Firebase API or cache.

  ## Parameters

    - client_code: The code of the client to retrieve.

  ## Examples

      iex> AngelTrading.Account.get_client("ABC123")
      {:ok, %{"body" => "encrypted_data"}}

  """
  def get_client(client_code) do
    Cache.get(
      "get_client_api_" <> client_code,
      {fn -> get("/clients/#{client_code}.json") end, []},
      :timer.hours(5)
    )
  end

  @doc """
  Get a user's client codes from the Firebase API or cache.

  ## Parameters

    - user_hash: The hash of the user to retrieve client codes for.

  ## Examples

      iex> AngelTrading.Account.get_client_codes("user123")
      {:ok, %{body: %{"ABC123" =>"ABC123", "DEF456" => "DEF456", ...}}}

  """
  def get_client_codes(user_hash) do
    Cache.get(
      "get_client_codes_api_" <> user_hash,
      {fn -> get("/users/#{user_hash}/clients.json") end, []},
      :timer.hours(5)
    )
  end

  @doc """
  Get user data from the Firebase API or cache.

  ## Parameters

    - user_hash: The hash of the user to retrieve.

  ## Examples

      iex> AngelTrading.Account.get_user("base64hash")
      {:ok, %{"body" => %{"totp_secret" => "xxxx"}}}

  """
  def get_user(user_hash) do
    Cache.get(
      "get_user_api_" <> user_hash,
      {fn -> get("/users/#{user_hash}.json") end, []},
      :timer.hours(5)
    )
  end

  @doc """
  Update a user's watchlist in the Firebase API and invalidate the user's cached data.

  ## Parameters

    - user_hash: The hash of the user to update the watchlist for.
    - watchlist: The new watchlist for the user.

  ## Examples

      iex> AngelTrading.Account.update_watchlist("user123", ["AAPL", "GOOG", "AMZN"])
      :ok

  """
  def update_watchlist(user_hash, watchlist) do
    case patch("/users/#{user_hash}.json", %{watchlist: watchlist}) do
      {:ok, %{body: %{"watchlist" => _}}} ->
        Cache.del("get_user_api_" <> user_hash)
        :ok

      e ->
        Logger.error("[API][Watchlist] Error updating watchlist.")
        IO.inspect(e)
        :error
    end
  end

  @doc """
  Set a user's tokens (client code, token, refresh token, feed token, PIN, and TOTP secret) in the Firebase API and invalidate the cached data.

  ## Parameters

    - user_hash: The hash of the user to set tokens for.
    - tokens: A map containing the following keys:
      - client_code: The client code.
      - token: The access token.
      - refresh_token: The refresh token.
      - feed_token: The feed token.
      - pin: The user's PIN.
      - totp_secret: The user's TOTP secret.

  ## Examples

      iex> tokens = %{"client_code" => "ABC123", "token" => "xyz", ...}
      iex> AngelTrading.Account.set_tokens("user123", tokens)
      :ok

  """
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
      Cache.del("get_client_api_" <> client_code)
      Cache.del("get_user_api_" <> user_hash)
      Cache.del("get_client_codes_api_" <> user_hash)
      :ok
    else
      e ->
        Logger.error("[API][Tokens] Error saving tokens")
        IO.inspect(e)
        :error
    end
  end
end
