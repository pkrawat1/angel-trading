defmodule AngelTradingWeb.PortfolioLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.{Account, API, Utils}
  import Number.Currency, only: [number_to_currency: 1, number_to_currency: 2]
  require Logger

  def mount(
        %{"client_code" => client_code},
        %{"user_hash" => user_hash},
        socket
      ) do
    client_code = client_code |> String.upcase()

    if connected?(socket) do
      :ok = AngelTradingWeb.Endpoint.subscribe("portfolio-for-#{client_code}")
      :timer.send_interval(2000, self(), :subscribe_to_feed)
    end

    user_clients =
      case Account.get_client_codes(user_hash) do
        {:ok, %{body: data}} when is_map(data) -> Map.values(data)
        _ -> []
      end

    socket =
      with true <- client_code in user_clients,
           {:ok, %{body: client_data}} when is_binary(client_data) <-
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
        |> assign(:quote, nil)
        |> assign(:candle_data, nil)
        |> get_portfolio_data()
      else
        _ ->
          socket
          |> put_flash(:error, "Invalid client")
          |> push_navigate(to: "/")
      end

    {:ok, socket}
  end

  def handle_params(
        _,
        _,
        %{assigns: %{live_action: :quote, quote: quote, client_code: client_code}} = socket
      )
      when is_nil(quote),
      do: {:noreply, push_patch(socket, to: ~p"/client/#{client_code}/portfolio")}

  def handle_params(_, _, socket), do: {:noreply, socket}

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
                 tokens: Enum.map(socket.assigns.holdings, & &1["symboltoken"])
               }
             ]
           }
         })}
      )
    else
      pid when is_pid(pid) ->
        Logger.info(
          "[Portfolio] web socket (#{socket_process} #{inspect(pid)}) already established"
        )

      e ->
        Logger.error("[Portfolio] Error connecting to web socket (#{socket_process})")
        IO.inspect(e)
    end

    {:noreply, socket}
  end

  def handle_info(
        %{payload: quote},
        %{assigns: %{live_action: :quote}} = socket
      ) do
    socket =
      if(quote.token == socket.assigns.quote["symbolToken"]) do
        {_, socket} =
          handle_event(
            "select-holding",
            %{
              "exchange" => socket.assigns.quote["exchange"],
              "symbol" => quote.token
            },
            socket
          )

        socket
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(
        %{payload: quote_data},
        %{assigns: %{holdings: holdings}} = socket
      ) do
    new_ltp = quote_data.last_traded_price / 100
    updated_holding = Enum.find(holdings, &(&1["symboltoken"] == quote_data.token))

    socket =
      if updated_holding && updated_holding["ltp"] != new_ltp do
        updated_holding =
          [%{updated_holding | "ltp" => new_ltp}]
          |> Utils.formatted_holdings()
          |> List.first()

        holdings =
          Enum.map(holdings, fn holding ->
            if holding["symboltoken"] == quote_data.token do
              updated_holding
            else
              holding
            end
          end)

        if(updated_holding) do
          socket
          |> stream_insert(:holdings, updated_holding, at: -1)
          |> Utils.calculated_overview(holdings)
        end
      end || socket

    {:noreply, socket}
  end

  def handle_event(
        "select-holding",
        %{"exchange" => exchange, "symbol" => symbol_token},
        %{assigns: %{token: token}} = socket
      ) do
    socket =
      with {:ok, %{"data" => %{"fetched" => [quote]}}} <-
             API.quote(token, exchange, symbol_token),
           {:ok, %{"data" => candle_data}} <-
             API.candle_data(
               token,
               exchange,
               symbol_token,
               "ONE_MINUTE",
               Timex.now()
               |> Timex.shift(weeks: -2)
               |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:{0m}"),
               Timex.now() |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:{0m}")
             ) do
        %{"ltp" => ltp, "close" => close} = quote
        ltp_percent = (ltp - close) / close * 100

        quote = Map.merge(quote, %{"ltp_percent" => ltp_percent, "is_gain_today?" => ltp > close})

        candle_data = candle_data |> Utils.formatted_candle_data() |> Jason.encode!()

        socket
        |> assign(quote: quote)
        |> assign(candle_data: candle_data)
      else
        _ ->
          socket
          |> assign(quote: nil)
          |> put_flash(:error, "[Quote] : Failed to fetch quote")
      end

    {:noreply, socket}
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
