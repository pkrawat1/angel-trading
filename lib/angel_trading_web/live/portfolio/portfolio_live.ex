defmodule AngelTradingWeb.PortfolioLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.{Account, API, Utils}
  import Number.Currency, only: [number_to_currency: 1, number_to_currency: 2]

  def mount(
        %{"client_code" => client_code},
        _session,
        socket
      ) do
    client_code = client_code |> String.upcase()

    if connected?(socket) do
      :ok = AngelTradingWeb.Endpoint.subscribe("portfolio-for-#{client_code}")
      :timer.send_interval(2000, self(), :subscribe_to_feed)
    end

    socket =
      with {:ok, %{body: client_data}} when is_binary(client_data) <-
             Account.get_client(client_code),
           {:ok,
            %{
              token: token,
              client_code: client_code,
              feed_token: feed_token,
              refresh_token: refresh_token
            }} <- Utils.decrypt(:client_tokens, client_data) do
        socket
        |> assign(:page_title, "Portfolio")
        |> assign(:token, token)
        |> assign(:client_code, client_code)
        |> assign(:feed_token, feed_token)
        |> assign(:refresh_token, refresh_token)
        |> get_portfolio_data()
      else
        _ ->
          socket
          |> put_flash(:error, "Invalid client")
          |> push_navigate(to: "/")
      end

    {:ok, socket}
  end

  def handle_info(
        :subscribe_to_feed,
        %{
          assigns: %{
            client_code: client_code,
            token: token,
            feed_token: feed_token
          }
        } = socket
      ) do
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

    {:noreply, socket}
  end

  def handle_info(%{payload: quote_data}, %{assigns: %{holdings: holdings}} = socket) do
    holdings =
      holdings
      |> Enum.map(fn holding ->
        if holding["symboltoken"] == quote_data.token do
          %{holding | "ltp" => quote_data.last_traded_price / 100}
        else
          holding
        end
      end)
      |> Utils.formatted_holdings()

    updated_holding = Enum.find(holdings, &(&1["symboltoken"] == quote_data.token))

    socket =
      if(updated_holding) do
        stream_insert(socket, :holdings, updated_holding, at: -1)
      else
        socket
      end

    {:noreply,
     socket
     |> Utils.calculated_overview(holdings)}
  end

  defp get_portfolio_data(%{assigns: %{token: token}} = socket) do
    with {:ok, %{"data" => profile}} <- API.profile(token),
         {:ok, %{"data" => holdings}} <- API.portfolio(token) do
      holdings = Utils.formatted_holdings(holdings)

      socket
      |> Utils.calculated_overview(holdings)
      |> assign(name: profile["name"])
      |> stream(
        :holdings,
        Enum.sort(holdings, &(&2["tradingsymbol"] >= &1["tradingsymbol"]))
      )
    else
      {:error, %{"message" => message}} ->
        socket
        |> put_flash(:error, message)
        |> push_navigate(to: "/")
    end
  end
end
