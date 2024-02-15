defmodule AngelTradingWeb.DashboardLive.Portfolio do
  use AngelTradingWeb, :live_component

  alias AngelTrading.{Account, API}

  def update(%{client_code: client_code} = assigns, socket) do
    {:ok,
     assign_async(socket, [:client_code, :client, :holdings, :profile, :funds, :dis_status], fn ->
       with {:ok, %{body: data}} when is_binary(data) <- Account.get_client(client_code),
            {:ok, %{token: token} = client} <- Utils.decrypt(:client_tokens, data),
            {:profile, {:ok, %{"data" => profile}}} <- {:profile, API.profile(token)},
            {:portfolio, {:ok, %{"data" => holdings}}} <-
              {:portfolio, API.portfolio(token)},
            {:funds, {:ok, %{"data" => funds}}} <- {:funds, API.funds(token)},
            {_, dis_status} <-
              API.verify_dis(token, holdings |> List.first() |> Map.get("isin", "")) do
         Process.send_after(self(), {:subscribe_to_feed, client_code}, 500)
         :timer.send_interval(30000, self(), {:subscribe_to_feed, client_code})

         {:ok,
          %{
            client_code: client_code,
            client: client,
            holdings: holdings,
            profile: profile,
            funds: funds,
            dis_status: dis_status
          }}
       else
         e ->
           {:error, e}
       end
     end)}
  end
end
