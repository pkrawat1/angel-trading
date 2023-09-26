defmodule AngelTradingWeb.DashboardLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.API
  import Number.Currency, only: [number_to_currency: 1, number_to_currency: 2]

  def mount(
        _params,
        %{"token" => token, "client_code" => client_code, "feed_token" => feed_token},
        socket
      ) do
    if connected?(socket) do
      :ok = AngelTradingWeb.Endpoint.subscribe("portfolio-for-#{client_code}")
      :timer.send_interval(10000, self(), :subscribe_to_feed)
    end

    {:ok,
     socket
     |> assign(:token, token)
     |> assign(:client_code, client_code)
     |> assign(:feed_token, feed_token)
     |> get_portfolio_data()}
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
    end

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
      |> formatted_holdings()

    updated_holding = Enum.find(holdings, &(&1["symboltoken"] == quote_data.token))

    socket =
      if(updated_holding) do
        stream_insert(socket, :holdings, updated_holding, at: -1)
      else
        socket
      end

    {:noreply,
     socket
     |> calculated_overview(holdings)}
  end

  defp get_portfolio_data(%{assigns: %{token: token}} = socket) do
    with {:ok, %{"data" => profile}} <- API.profile(token),
         {:ok, %{"data" => holdings}} <- API.portfolio(token) do
      holdings = formatted_holdings(holdings)

      socket
      |> calculated_overview(holdings)
      |> assign(name: profile["name"])
      |> stream(
        :holdings,
        Enum.sort(holdings, &(&2["tradingsymbol"] >= &1["tradingsymbol"]))
      )
    else
      {:error, %{"message" => message}} ->
        put_flash(socket, :error, message)
    end
  end

  # Using float calculation as of now. Since most of the data is coming from angel api.
  # I could add ex_money to manage calculations in decimal money format.
  defp formatted_holdings(holdings) do
    Enum.map(holdings, fn %{
                            "authorisedquantity" => _,
                            "averageprice" => averageprice,
                            "close" => close,
                            "collateralquantity" => _,
                            "collateraltype" => _,
                            "exchange" => _,
                            "haircut" => _,
                            "isin" => _,
                            "ltp" => ltp,
                            "product" => _,
                            "profitandloss" => _,
                            "quantity" => quantity,
                            "realisedquantity" => _,
                            "symboltoken" => symboltoken,
                            "t1quantity" => _,
                            "tradingsymbol" => _
                          } = holding ->
      invested = quantity * averageprice
      current = quantity * ltp
      overall_gain_or_loss = quantity * (ltp - averageprice)
      overall_gain_or_loss_percent = overall_gain_or_loss / invested * 100
      todays_profit_or_loss = quantity * (ltp - close)
      todays_profit_or_loss_percent = todays_profit_or_loss / invested * 100
      ltp_percent = (ltp - close) / close * 100

      Map.merge(holding, %{
        "invested" => invested,
        "current" => current,
        "in_overall_profit?" => current > invested,
        "is_gain_today?" => ltp > close,
        "overall_gain_or_loss" => overall_gain_or_loss,
        "overall_gain_or_loss_percent" => overall_gain_or_loss_percent,
        "todays_profit_or_loss" => todays_profit_or_loss,
        "todays_profit_or_loss_percent" => todays_profit_or_loss_percent,
        "ltp_percent" => ltp_percent,
        id: symboltoken
      })
    end)
  end

  defp calculated_overview(socket, holdings) do
    total_invested = holdings |> Enum.map(& &1["invested"]) |> Enum.sum()
    total_overall_gain_or_loss = holdings |> Enum.map(& &1["overall_gain_or_loss"]) |> Enum.sum()
    total_todays_gain_or_loss = holdings |> Enum.map(& &1["todays_profit_or_loss"]) |> Enum.sum()

    assign(socket,
      holdings: holdings |> Enum.sort(&(&2["tradingsymbol"] >= &1["tradingsymbol"])),
      total_invested: total_invested,
      total_current: holdings |> Enum.map(& &1["current"]) |> Enum.sum(),
      total_overall_gain_or_loss: total_overall_gain_or_loss,
      total_todays_gain_or_loss: total_todays_gain_or_loss,
      in_overall_profit_today?: total_todays_gain_or_loss > 0,
      in_overall_profit?: total_overall_gain_or_loss > 0,
      total_overall_gain_or_loss_percent: total_overall_gain_or_loss / total_invested * 100,
      total_todays_gain_or_loss_percent: total_todays_gain_or_loss / total_invested * 100
    )
  end
end
