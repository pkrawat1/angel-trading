defmodule AngelTrading.API do
  use Tesla

  @routes %{
    socket: "ws://smartapisocket.angelone.in/smart-stream",
    login: "rest/auth/angelbroking/user/v1/loginByPassword",
    logout: "rest/secure/angelbroking/user/v1/logout",
    profile: "rest/secure/angelbroking/user/v1/getProfile",
    portfolio: "rest/secure/angelbroking/portfolio/v1/getHolding"
  }

  def socket(client_code, token, feed_token) do
    AngelTrading.WebSocket.start_link(%{
      client_code: client_code,
      token: token,
      feed_token: feed_token
    })
  end

  def login(%{"clientcode" => _, "password" => _, "totp" => _} = params) do
    client()
    |> post(@routes.login, params)
    |> gen_response()
  end

  def logout(token, clientcode) do
    client(token)
    |> post(@routes.logout, %{"clientcode" => clientcode})
    |> gen_response()
  end

  def profile(token) do
    client(token)
    |> get(@routes.profile)
    |> gen_response()
  end

  def portfolio(token) do
    client(token)
    |> get(@routes.portfolio)
    |> gen_response()
  end

  defp client(token \\ nil) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"X-UserType", "USER"},
      {"X-SourceID", "WEB"},
      {"X-ClientLocalIP", Application.get_env(:angel_trading, :local_ip)},
      {"X-ClientPublicIP", Application.get_env(:angel_trading, :public_ip)},
      {"X-MACAddress", Application.get_env(:angel_trading, :mac_address)},
      {"X-PrivateKey", Application.get_env(:angel_trading, :api_key)}
    ]

    headers =
      if token do
        [{"authorization", "Bearer " <> token} | headers]
      else
        headers
      end

    middleware = [
      {Tesla.Middleware.BaseUrl, Application.get_env(:angel_trading, :api_endpoint)},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers, headers},
      {Tesla.Middleware.Retry,
       delay: 1000,
       max_retries: 10,
       max_delay: 4_000,
       should_retry: fn
         {:ok, %{status: status}} when status in [400, 403, 500] -> true
         {:ok, _} -> false
         {:error, _} -> true
       end}
    ]

    Tesla.client(middleware)
  end

  defp gen_response({:ok, %{body: %{"message" => message} = body} = _env})
       when message == "SUCCESS" do
    # IO.inspect(_env)
    {:ok, body}
  end

  defp gen_response({:ok, %{body: body} = _env}) do
    # IO.inspect(_env)
    {:error, body}
  end

  defp gen_response({:error, %{body: body}}), do: {:error, body}
end
