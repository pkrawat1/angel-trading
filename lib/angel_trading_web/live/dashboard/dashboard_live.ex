defmodule AngelTradingWeb.DashboardLive do
  use AngelTradingWeb, :live_view

  alias AngelTrading.Account
  alias AngelTradingWeb.Dashboard.Components.PortfolioComponent

  def mount(_params, %{"user_hash" => user_hash}, socket) do
    # :timer.send_interval(2000, self(), :subscribe_to_feed)

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
          {:ok, %{body: data}} ->
            Map.new(data, fn {key, value} ->
              {String.to_atom(key), value}
            end)

          _ ->
            nil
        end
      end)
      |> Enum.filter(&(!is_nil(&1)))

    assign(socket, :clients, clients)
  end

  def handle_info(:subscribe_to_feed, %{assigns: %{clients: clients}} = socket) do
    Enum.each(clients, fn %{client_code: client_code, token: token, feed_token: feed_token} ->
      socket_process = :"#{client_code}"

      unless Process.whereis(socket_process) do
        AngelTrading.API.socket(client_code, token, feed_token)

        WebSockex.send_frame(
          socket_process,
          {:text,
           Jason.encode!(%{
             correlationID: "abcde12345",
             action: 1,
             params: %{
               mode: 2,
               tokenList: [
                 %{
                   exchangeType: 1,
                   tokens: Enum.map(socket.assigns.holdings, & &1["symboltoken"])
                 }
               ]
             }
           })}
        )
      end
    end)

    {:noreply, socket}
  end

  def handle_info(%{payload: quote_data}, %{assigns: %{holdings: holdings}} = socket) do

    {:noreply, socket}
    # holdings =
      # holdings
      # |> Enum.map(fn holding ->
        # if holding["symboltoken"] == quote_data.token do
          # %{holding | "ltp" => quote_data.last_traded_price / 100 + Enum.take_rand(100)}
        # else
          # holding
        # end
      # end)
      # |> formatted_holdings()
#
    # updated_holding = Enum.find(holdings, &(&1["symboltoken"] == quote_data.token))
#
    # socket =
      # if(updated_holding) do
        # stream_insert(socket, :holdings, updated_holding, at: -1)
      # else
        # socket
      # end

    # {:noreply,
     # socket
     # |> calculated_overview(holdings)}
  end
end
