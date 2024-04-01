defmodule AngelTradingWeb.OrdersLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.{Account, API, Utils}
  require Logger

  embed_templates "*"

  def mount(%{"client_code" => client_code}, %{"user_hash" => user_hash}, socket) do
    client_code = String.upcase(client_code)

    if connected?(socket) do
      :ok = Phoenix.PubSub.subscribe(AngelTrading.PubSub, "quote-stream-#{client_code}")
      :ok = Phoenix.PubSub.subscribe(AngelTrading.PubSub, "order-stream-#{client_code}")
      Process.send_after(self(), :subscribe_to_feed, 500)
      :timer.send_interval(30000, self(), :subscribe_to_feed)
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
        |> assign(:page_title, "Orders")
        |> assign(:token, token)
        |> assign(:client_code, client_code)
        |> assign(:feed_token, feed_token)
        |> assign(:refresh_token, refresh_token)
        |> assign(:quote, nil)
        |> get_order_data()
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
      do: {:noreply, push_patch(socket, to: ~p"/client/#{client_code}/orders")}

  def handle_params(_, _, %{assigns: %{live_action: :show}} = socket),
    do: {:noreply, socket |> assign(:quote, nil)}

  def handle_params(params, _, socket), do: {:noreply, assign(socket, params: params)}

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
    socket_process = :"#{client_code}-quote-stream"
    order_socket_process = :"#{client_code}-order-stream"

    subscribe_to_feed = fn ->
      WebSockex.cast(
        socket_process,
        {:send,
         {:text,
          Jason.encode!(%{
            correlationID: client_code,
            action: 1,
            params: %{
              mode: 3,
              tokenList: [
                %{
                  exchangeType: 1,
                  tokens: Enum.map(socket.assigns.order_book, & &1.symbol_token)
                }
              ]
            }
          })}}
      )
    end

    with nil <- Process.whereis(socket_process),
         {:ok, pid} when is_pid(pid) <-
           API.socket(client_code, token, feed_token, "quote-stream-" <> client_code) do
      Logger.info("[Order] web socket (#{socket_process}) started")
      subscribe_to_feed.()
    else
      pid when is_pid(pid) ->
        Logger.info("[Order] web socket (#{socket_process} #{inspect(pid)}) already established")
        subscribe_to_feed.()

      e ->
        Logger.error("[Order] Error connecting to web socket (#{socket_process})")
        IO.inspect(e)
        quote_fallback(socket)
    end

    with nil <- Process.whereis(order_socket_process),
         {:ok, pid} when is_pid(pid) <-
           API.order_socket(client_code, token, feed_token, "order-stream-" <> client_code) do
      WebSockex.cast(order_socket_process, :subscriber_tick)
      Logger.info("[Order] Order status web socket (#{order_socket_process}) started")
    else
      pid when is_pid(pid) ->
        WebSockex.cast(order_socket_process, :subscriber_tick)

        Logger.info(
          "[Order] Order status web socket (#{order_socket_process} #{inspect(pid)}) already established"
        )

      e ->
        Logger.error(
          "[Order] Error connecting to order status web socket (#{order_socket_process})"
        )

        IO.inspect(e)
    end

    {:noreply, socket}
  end

  def handle_info(
        %{topic: topic, payload: new_quote},
        %{assigns: %{client_code: client_code, live_action: :quote, quote: quote_data}} = socket
      )
      when topic == "quote-stream-" <> client_code do
    socket =
      if(new_quote.token == quote_data.symbol_token) do
        ltp = new_quote.last_traded_price
        close = new_quote.close_price
        ltp_percent = (ltp - close) / close * 100

        assign(
          socket,
          quote:
            Map.merge(quote_data, %{
              ltp: ltp,
              ltp_percent: ltp_percent,
              is_gain_today?: ltp > close,
              close: close,
              open: new_quote.open_price_day,
              low: new_quote.low_price_day,
              high: new_quote.high_price_day,
              tot_buy_quan: new_quote.total_buy_quantity,
              tot_sell_quan: new_quote.total_sell_quantity,
              depth: %{
                buy:
                  Enum.map(
                    new_quote.best_five.buy,
                    &%{quantity: &1.quantity, price: &1.price}
                  ),
                sell:
                  Enum.map(
                    new_quote.best_five.sell,
                    &%{quantity: &1.quantity, price: &1.price}
                  )
              }
            })
        )
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(
        %{topic: topic, payload: quote_data},
        %{assigns: %{client_code: client_code, order_book: order_book}} = socket
      )
      when topic == "quote-stream-" <> client_code do
    new_ltp = quote_data.last_traded_price
    close = quote_data.close_price
    ltp_percent = (new_ltp - close) / close * 100
    updated_orders = Enum.filter(order_book, &(&1.symbol_token == quote_data.token))

    socket =
      if updated_orders != [] do
        updated_orders
        |> Enum.filter(&(&1.ltp != new_ltp))
        |> Enum.reduce(socket, fn updated_order, socket ->
          updated_order =
            updated_order
            |> Map.replace(:ltp, new_ltp)
            |> Map.replace(:close, close)
            |> Map.replace(:ltp_percent, ltp_percent)
            |> Map.replace(:is_gain_today?, close < new_ltp)
            |> Map.replace(
              :gains_or_loss,
              if(updated_order.transaction_type == "SELL", do: -1, else: 1) *
                updated_order.filled_shares *
                (new_ltp - updated_order.average_price)
            )

          socket
          |> stream_insert(
            :order_book,
            updated_order,
            at: -1
          )
        end)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(
        %{topic: topic, payload: new_order},
        %{assigns: %{token: token, client_code: client_code, order_book: order_book}} = socket
      )
      when topic == "order-stream-" <> client_code do
    API.reset_cache(token)

    updated_order =
      Enum.find(order_book, &(&1.order_id == new_order.order_id))

    socket =
      case {updated_order, new_order} do
        {%{status: updated_order_status}, %{orderid: order_id, status: order_status}}
        when bit_size(order_id) > 0 and updated_order_status not in ["cancelled", "rejected"] and
               order_status in ["cancelled", "rejected"] ->
          socket
          |> stream_delete(:order_book, new_order)
          |> assign(order_book: Enum.filter(order_book, &(&1.order_id != new_order.order_id)))

        {%{}, _} ->
          updated_order = Map.merge(updated_order, new_order)

          order_book =
            Enum.map(order_book, fn order ->
              if updated_order.order_id == order.order_id do
                updated_order
              else
                order
              end
            end)

          socket
          |> stream_insert(
            :order_book,
            updated_order,
            at: -1
          )
          |> assign(order_book: order_book)

        {_, %{orderid: order_id}}
        when bit_size(order_id) > 0 ->
          socket
          |> stream_insert(:order_book, new_order, at: -1)
          |> assign(order_book: [new_order | order_book])

        _ ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event(
        "select-holding",
        %{"exchange" => exchange, "symbol" => symbol_token, "selected-order-id" => order_id},
        %{assigns: %{token: token, order_book: order_book}} = socket
      ) do
    socket =
      with {:ok, %{"data" => %{fetched: [quote_data]}}} <-
             API.quote(token, exchange, [symbol_token]) do
        %{ltp: ltp, close: close} = quote_data
        ltp_percent = (ltp - close) / close * 100

        quote_data =
          Map.merge(quote_data, %{ltp_percent: ltp_percent, is_gain_today?: ltp > close})

        socket
        |> assign(quote: quote_data)
        |> assign(selected_order: Enum.find(order_book, &(&1.order_id == order_id)))
      else
        _ ->
          socket
          |> put_flash(:error, "[Quote] : Failed to fetch quote")
      end

    {:noreply, socket}
  end

  def handle_event(
        "cancel-order",
        %{"id" => order_id},
        %{assigns: %{token: token, client_code: client_code}} = socket
      ) do
    socket =
      with {:ok, %{"data" => %{order_id: order_id}}} <- API.cancel_order(token, order_id) do
        socket
        |> push_navigate(to: ~p"/client/#{client_code}/orders")
        |> put_flash(:info, "Order[#{order_id}] cancelled.")
      else
        e ->
          Logger.error("[Order] Error cancelling order.")
          IO.inspect(e)

          socket
          |> push_navigate(to: ~p"/client/#{client_code}/orders")
          |> put_flash(:error, "Failed to place order.")
      end

    {:noreply, socket}
  end

  defp get_order_data(%{assigns: %{token: token}} = socket) do
    with {:ok, %{"data" => profile}} <- API.profile(token),
         {:ok, %{"data" => funds}} <- API.funds(token),
         {:ok, %{"data" => %{orders: order_book}}} <- API.order_book(token) do
      order_book = Enum.sort(order_book || [], &(&1.order_id >= &2.order_id))

      socket
      |> assign(name: profile.name)
      |> assign(funds: funds)
      |> stream_configure(:order_book, dom_id: &"order-#{&1.order_id}")
      |> stream(:order_book, order_book || [])
      |> assign(order_book: order_book || [])
    else
      {:error, %{"message" => message}} ->
        socket
        |> put_flash(:error, message)
        |> push_navigate(to: "/")
    end
  end

  defp quote_fallback(
         %{
           assigns: %{
             token: token,
             order_book: order_book,
             client_code: client_code
           }
         } = socket
       ) do
    with {:ok, %{"data" => %{"fetched" => quotes}}} <-
           API.quote(token, "NSE", Enum.map(order_book, & &1.symbol_token)) do
      Enum.each(quotes, fn quote_data ->
        send(
          self(),
          %{
            topic: "quote-stream-" <> client_code,
            payload:
              Map.merge(quote_data, %{
                last_traded_price: quote_data.ltp * 100,
                token: quote_data.symbol_token,
                close_price: quote_data.close * 100
              })
          }
        )
      end)
    end

    socket
  end
end
