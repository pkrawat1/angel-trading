defmodule AngelTradingWeb.DashboardLive do
  use AngelTradingWeb, :live_view

  alias AngelTrading.{Account, API, Utils}
  alias AngelTradingWeb.Dashboard.Components.PortfolioComponent

  def mount(_params, %{"user_hash" => user_hash}, socket) do
    :timer.send_interval(5000, self(), :subscribe_to_feed)

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:user_hash, user_hash)
     |> get_portfolio_data()}
  end

  defp get_portfolio_data(socket) do
    clients =
      Account.get_client_codes(socket.assigns.user_hash)
      |> case do
        {:ok, %{body: data}} when is_map(data) -> Map.keys(data)
        _ -> []
      end
      |> Enum.map(fn client_code ->
        case Account.get_client(client_code) do
          {:ok, %{body: data}} when is_binary(data) ->
            {:ok, data} = Utils.decrypt(:client_tokens, data)

            Map.new(data, fn {key, value} ->
              {String.to_atom(key), value}
            end)

          _ ->
            nil
        end
      end)
      |> Enum.map(fn
        %{token: token} = client ->
          with {:ok, %{"data" => profile}} <- API.profile(token),
               {:ok, %{"data" => holdings}} <- API.portfolio(token) do
            Map.merge(client, %{
              id: client.client_code,
              holdings: Utils.formatted_holdings(holdings),
              profile: profile
            })
          else
            _ ->
              nil
          end

        _ ->
          nil
      end)
      |> Enum.filter(&(!is_nil(&1)))

    assign(socket, :clients, clients)
  end

  def handle_info(:subscribe_to_feed, %{assigns: %{clients: clients}} = socket) do
    Enum.each(clients, fn %{
                            client_code: client_code,
                            token: token,
                            feed_token: feed_token,
                            holdings: holdings
                          } ->
      socket_process = :"#{client_code}"

      unless Process.whereis(socket_process) do
        AngelTrading.API.socket(client_code, token, feed_token)

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
      end
    end)

    {:noreply, socket}
  end

  def handle_info(
        %{topic: "portfolio-for-" <> client_code, payload: quote_data},
        %{assigns: %{clients: clients}} = socket
      ) do
    new_ltp = quote_data.last_traded_price / 100
    client = Enum.find(clients, &(&1.client_code == client_code))

    holding = Enum.find(client.holdings, &(&1["symboltoken"] == quote_data.token))

    if holding && holding["ltp"] != new_ltp do
      client =
        %{
          client
          | holdings:
              client.holdings
              |> Enum.map(fn holding ->
                if holding["symboltoken"] == quote_data.token do
                  %{holding | "ltp" => new_ltp}
                else
                  holding
                end
              end)
              |> Utils.formatted_holdings()
        }

      send_update(PortfolioComponent, Map.to_list(client))
    end

    {:noreply, socket}
  end
end
