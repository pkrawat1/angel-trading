defmodule AngelTrading.Auth do
  use Tesla

  def login(client_code, password, totp) do
    client()
    |> post("rest/auth/angelbroking/user/v1/loginByPassword", %{
      clientcode: client_code,
      password: password,
      totp: totp
    })
  end

  def client(token \\ nil) do
    headers = [
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"X-UserType", "USER"},
      {"X-SourceID", "WEB"},
      {"X-ClientLocalIP", "CLIENT_LOCAL_IP"},
      {"X-ClientPublicIP", "CLIENT_PUBLIC_IP"},
      {"X-MACAddress", "MAC_ADDRESS"},
      {"X-PrivateKey", "API_KEY"}
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
      {Tesla.Middleware.Headers, headers}
    ]

    Tesla.client(middleware)
  end
end
