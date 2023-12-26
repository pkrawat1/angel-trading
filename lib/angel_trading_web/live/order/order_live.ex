defmodule AngelTradingWeb.OrderLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.{Account, API, Utils}
  require Logger

  def mount(
        %{
          "client_code" => client_code,
          "symbol_token" => symbol_token,
          "exchange" => exchange,
          "transaction_type" => transaction_type,
          "trading_symbol" => trading_symbol
        },
        %{"user_hash" => user_hash},
        socket
      ) do
    client_code = String.upcase(client_code)

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
        |> assign(:page_title, "New Orders")
        |> assign(:token, token)
        |> assign(:client_code, client_code)
        |> assign(:feed_token, feed_token)
        |> assign(:refresh_token, refresh_token)
        |> assign(:order, %{
          type: "LIMIT",
          price: nil,
          quantity: nil,
          transaction_type: transaction_type,
          exchange: exchange,
          symbol_token: symbol_token,
          trading_symbol: trading_symbol,
          ltp: 0.0,
          close: 0.0,
          ltp_percent: 0.0,
          is_gain_today?: true
        })
        |> get_profile_data()
      else
        _ ->
          socket
          |> put_flash(:error, "Invalid client")
          |> push_navigate(to: "/")
      end

    IO.inspect(socket.assigns.order)
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

    with nil <- Process.whereis(socket_process),
         {:ok, ^socket_process} <- AngelTrading.API.socket(client_code, token, feed_token) do
      subscribe_to_quote_feed(socket)
    else
      pid when is_pid(pid) ->
        Logger.info(
          "[Watchlist] web socket (#{socket_process} #{inspect(pid)}) already established"
        )

      e ->
        Logger.error("[Watchlist] Error connecting to web socket (#{socket_process})")
        IO.inspect(e)
    end

    {:noreply, socket}
  end

  def handle_info(
        %{payload: quote_data},
        socket
      ) do
    new_ltp = quote_data.last_traded_price / 100
    close = quote_data.close_price / 100
    ltp_percent = (new_ltp - close) / close * 100
    updated_order = socket.assigns.order

    socket =
      if updated_order[:ltp] != new_ltp do
        updated_order =
          %{
            updated_order
            | ltp: new_ltp,
              close: close,
              ltp_percent: ltp_percent,
              is_gain_today?: new_ltp > close
          }

        assign(socket, order: updated_order)
      end || socket

    {:noreply, socket}
  end

  def handle_event(
        "validate-order",
        %{"order" => %{"price" => price, "quantity" => quantity}},
        socket
      ) do
    {:noreply, assign(socket, order: %{socket.assigns.order | price: price, quantity: quantity})}
  end

  def handle_event("toggle-order-type", %{"type" => type}, socket) do
    {:noreply, assign(socket, order: %{socket.assigns.order | type: type})}
  end

  def handle_event(
        "place-order",
        %{"order" => %{"price" => price, "quantity" => quantity}},
        %{assigns: %{order: order, token: token, client_code: client_code}} = socket
      ) do
    socket =
      with {:ok, %{"data" => %{"orderid" => order_id}}} <-
             API.place_order(token, %{
               exchange: order.exchange,
               trading_symbol: order.trading_symbol,
               symbol_token: order.symbol_token,
               quantity: quantity,
               transaction_type: order.transaction_type,
               order_type: order.type,
               variety: "NORMAL",
               product_type: "DELIVERY",
               price: price
             }) do
        socket
        |> push_navigate(to: ~p"/client/#{client_code}/orders")
        |> put_flash(:info, "Order[#{order_id}] placed successfully")
        |> assign(order: %{type: "LIMIT", price: nil, quantity: nil})
      else
        e ->
          Logger.error("[Watchlist][Order] Error placing order")
          IO.inspect(e)

          socket
          |> push_navigate(to: ~p"/client/#{client_code}/orders")
          |> put_flash(:error, "Failed to place order.")
      end

    {:noreply, socket}
  end

  defp get_profile_data(%{assigns: %{token: token}} = socket) do
    with {:ok, %{"data" => profile}} <- API.profile(token),
         {:ok, %{"data" => funds}} <- API.funds(token) do
      socket
      |> assign(name: profile["name"])
      |> assign(funds: funds)
    else
      {:error, %{"message" => message}} ->
        socket
        |> put_flash(:error, message)
        |> push_navigate(to: "/")
    end
  end

  defp subscribe_to_quote_feed(%{assigns: %{client_code: client_code, order: order}} = socket) do
    WebSockex.send_frame(
      :"#{client_code}",
      {:text,
       Jason.encode!(%{
         correlationID: client_code,
         action: 1,
         params: %{
           mode: 2,
           tokenList: [
             %{
               exchangeType: 1,
               tokens: [order.symbol_token]
             }
           ]
         }
       })}
    )

    socket
  end
end
