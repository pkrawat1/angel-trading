defmodule AngelTradingWeb.DashboardLive.Portfolio do
  use AngelTradingWeb, :live_component
  require Logger

  embed_templates "*"

  alias AngelTrading.{Account, API, Utils}

  def update(%{client_code: client_code}, socket) do
    live_view_pid = self()
    :ok = Phoenix.PubSub.subscribe(AngelTrading.PubSub, "quote-stream-#{client_code}")

    {:ok,
     socket
     |> assign_async(:client, fn ->
       with {:ok, %{body: data}} when is_binary(data) <- Account.get_client(client_code),
            {:ok, %{token: token} = client} <- Utils.decrypt(:client_tokens, data),
            {:profile, {:ok, %{"data" => profile}}} <- {:profile, API.profile(token)},
            {:portfolio, {:ok, %{"data" => holdings}}} <-
              {:portfolio, API.portfolio(token)},
            {:funds, {:ok, %{"data" => funds}}} <- {:funds, API.funds(token)},
            {_, dis_status} <-
              API.verify_dis(token, holdings |> List.first() |> Map.get("isin", "")) do
         symbol_tokens = Enum.map(holdings, & &1["symboltoken"])

         Process.send_after(
           live_view_pid,
           {:subscribe_to_feed,
            %{
              client_code: client_code,
              symbol_tokens: symbol_tokens,
              token: client.token,
              feed_token: client.feed_token
            }},
           500
         )

         :timer.send_interval(
           30000,
           live_view_pid,
           {:subscribe_to_feed,
            %{
              client_code: client_code,
              symbol_tokens: symbol_tokens,
              token: client.token,
              feed_token: client.feed_token
            }}
         )

         client =
           Map.merge(client, %{
             holdings: holdings,
             profile: profile,
             funds: funds,
             dis_status: dis_status
           })

         {:ok,
          %{
            client: Map.merge(client, calculated_overview(client))
          }}
       else
         e ->
           Logger.error("[Dashboard] Unable to fetch data")
           IO.inspect(e)
           {:error, :client_error}
       end
     end)}
  end

  def update(%{quote_data: quote_data}, %{assigns: %{client: %{result: %{} = client}}} = socket) do
    new_ltp = quote_data.last_traded_price

    updated_holding = Enum.find(client.holdings, &(&1["symboltoken"] == quote_data.token))

    if updated_holding && updated_holding["ltp"] != new_ltp do
      client = %{
        client
        | holdings:
            client.holdings
            |> Enum.map(fn holding ->
              if holding["symboltoken"] == quote_data.token do
                [%{updated_holding | "ltp" => new_ltp}]
                |> Utils.formatted_holdings()
                |> List.first()
              else
                holding
              end
            end)
      }

      {:ok,
       assign_async(socket, :client, fn ->
         {:ok, %{client: Map.merge(client, calculated_overview(client))}}
       end)}
    else
      {:ok, socket}
    end
  end

  def update(_, socket), do: {:ok, socket}

  def calculated_overview(client) do
    client
    |> Map.get(:holdings)
    |> Utils.formatted_holdings()
    |> Utils.calculated_overview()
  end
end
