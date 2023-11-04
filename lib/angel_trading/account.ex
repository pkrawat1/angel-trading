defmodule AngelTrading.Account do
  use Tesla

  plug Tesla.Middleware.BaseUrl, Application.get_env(:angel_trading, :firebase_api, "") 

  plug Tesla.Middleware.Headers, []
  plug Tesla.Middleware.Query, auth: Application.get_env(:angel_trading, :firebase_token, "") 
  plug Tesla.Middleware.JSON

  def get_clients() do
    get("/clients.json")
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
      patch("/users/#{name}/clients.json", %{client_code => client_code})
      put("clients/#{client_code}.json", %{
        "client_code" => client_code,
        "token" => token,
        "refresh_token" => refresh_token,
        "feed_token" => feed_token
      })
  end
end
