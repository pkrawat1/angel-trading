defmodule AngelTradingWeb.DashboardLive do
  use AngelTradingWeb, :live_view

  alias AngelTrading.{Account, API, Utils}
  alias AngelTradingWeb.Dashboard.Components.PortfolioComponent
  require Logger

  def mount(_params, %{"user_hash" => user_hash}, socket) do
    :timer.send_interval(2000, self(), :subscribe_to_feed)

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:user_hash, user_hash)
     |> get_portfolio_data}
  end

  defp get_portfolio_data(socket) do
    async_fn = fn ->
      {:ok,
       %{
         clients:
           Account.get_client_codes(socket.assigns.user_hash)
           |> case do
             {:ok, %{body: data}} when is_map(data) -> Map.values(data)
             _ -> []
           end
           |> Task.async_stream(fn client_code ->
             with {:ok, %{body: data}} when is_binary(data) <- Account.get_client(client_code),
                  {:ok, %{token: token} = client} <- Utils.decrypt(:client_tokens, data),
                  {:ok, %{"data" => profile}} <- API.profile(token),
                  {:ok, %{"data" => holdings}} <- API.portfolio(token),
                  {:ok, %{"data" => funds}} <- API.funds(token),
                  :ok <- AngelTradingWeb.Endpoint.subscribe("portfolio-for-#{client_code}") do
               Map.merge(client, %{
                 id: client.client_code,
                 holdings: holdings,
                 profile: profile,
                 funds: funds
               })
             else
               _ ->
                 nil
             end
           end)
           |> Enum.map(&elem(&1, 1))
           |> Enum.filter(&(!is_nil(&1)))
       }}
    end

    assign_async(socket, :clients, async_fn)
  end

  def handle_info(:subscribe_to_feed, %{assigns: %{clients: clients}} = socket) do
    Enum.each(clients.result || [], fn %{
                                         client_code: client_code,
                                         token: token,
                                         feed_token: feed_token,
                                         holdings: holdings
                                       } ->
      socket_process = :"#{client_code}"

      with nil <- Process.whereis(socket_process),
           {:ok, ^socket_process} <- AngelTrading.API.socket(client_code, token, feed_token) do
        WebSockex.send_frame(
          socket_process,
          {:text,
           Jason.encode!(%{
             correlationID: client_code,
             action: 1,
             params: %{
               mode: 2,
               tokenList: [
                 %{
                   exchangeType: 1,
                   tokens: Enum.map(holdings, & &1["symboltoken"])
                 }
               ]
             }
           })}
        )
      else
        pid when is_pid(pid) ->
          Logger.info(
            "[Dashboard] web socket (#{socket_process} #{inspect(pid)}) already established"
          )

        e ->
          with {:ok, %{"data" => %{"fetched" => quotes}}} <-
                 API.quote(token, "NSE", Enum.map(holdings, & &1["symboltoken"])) do
            Enum.each(quotes, fn quote_data ->
              send(
                self(),
                %{
                  topic: "portfolio-for-" <> client_code,
                  payload:
                    Map.merge(quote_data, %{
                      last_traded_price: quote_data["ltp"] * 100,
                      token: quote_data["symbolToken"]
                    })
                }
              )
            end)
          end

          Logger.error("[Dashboard] Error connecting to web socket (#{socket_process})")
          IO.inspect(e)
      end
    end)

    {:noreply, socket}
  end

  def handle_info(
        %{topic: "portfolio-for-" <> client_code, payload: quote_data},
        %{assigns: %{clients: clients}} = socket
      ) do
    new_ltp = quote_data.last_traded_price / 100
    client = Enum.find(clients.result, &(&1.client_code == client_code))

    updated_holding = Enum.find(client.holdings, &(&1["symboltoken"] == quote_data.token))

    updated_client =
      if updated_holding && updated_holding["ltp"] != new_ltp do
        updated_holding =
          [%{updated_holding | "ltp" => new_ltp}]
          |> Utils.formatted_holdings()
          |> List.first()

        %{
          client
          | holdings:
              client.holdings
              |> Enum.map(fn holding ->
                if holding["symboltoken"] == quote_data.token do
                  updated_holding
                else
                  holding
                end
              end)
        }
      else
        client
      end

    {:noreply,
     assign_async(socket, :clients, fn ->
       {:ok,
        %{
          clients:
            Enum.map(clients.result, fn client ->
              if client.client_code == updated_client.client_code do
                updated_client
              else
                client
              end
            end)
        }}
     end)}
  end
end
