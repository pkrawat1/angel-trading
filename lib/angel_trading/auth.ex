defmodule AngelTrading.Auth do
  use Tesla

  @routes %{
    login: "rest/auth/angelbroking/user/v1/loginByPassword"
  }

  def login(client_code, password, totp) do
    data = %{
      clientcode: client_code,
      password: password,
      totp: totp
    }

    client()
    |> post(@routes.login, data)
    |> gen_response()
  end

  defp client(token \\ nil) do
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

  defp gen_response(env) do
    {:ok, %{body: %{body: body}}} = env
    body = Jason.decode!(body)

    if body["message"] == "SUCCESS" do
      {:ok, body}
    else
      {:error, body}
    end
  end
end
