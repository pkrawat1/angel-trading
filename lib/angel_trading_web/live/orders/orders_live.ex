defmodule AngelTradingWeb.OrdersLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.{Account, API, Utils}
  require Logger

  embed_templates "*"

  def mount(%{"client_code" => client_code}, %{"user_hash" => user_hash}, socket) do
    client_code = String.upcase(client_code)

    if connected?(socket) do
      :ok = Phoenix.PubSub.subscribe(AngelTrading.PubSub, "quote-stream-#{client_code}")
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
    socket_process = :"#{client_code}"

    subscribe_to_feed = fn ->
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
                 tokens: Enum.map(socket.assigns.order_book, & &1["symboltoken"])
               }
             ]
           }
         })}
      )
    end

    with nil <- Process.whereis(socket_process),
         {:ok, pid} when is_pid(pid) <-
           API.socket(client_code, token, feed_token, "quote-stream-" <> client_code) do
      subscribe_to_feed.()
    else
      pid when is_pid(pid) ->
        Logger.info("[Order] web socket (#{socket_process} #{inspect(pid)}) already established")
        subscribe_to_feed.()

      e ->
        Logger.error("[Order] Error connecting to web socket (#{socket_process})")
        IO.inspect(e)
    end

    {:noreply, quote_fallback(socket)}
  end

  def handle_info(
        %{topic: topic, payload: new_quote},
        %{assigns: %{client_code: client_code, live_action: :quote, quote: quote}} = socket
      )
      when topic == "quote-stream-" <> client_code do
    socket =
      if(new_quote.token == quote["symbolToken"]) do
        ltp = new_quote.last_traded_price / 100
        close = new_quote.close_price / 100
        ltp_percent = (ltp - close) / close * 100

        assign(
          socket,
          quote:
            Map.merge(quote, %{
              "ltp" => ltp,
              "ltp_percent" => ltp_percent,
              "is_gain_today?" => ltp > close
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
    new_ltp = quote_data.last_traded_price / 100
    close = quote_data.close_price / 100
    ltp_percent = (new_ltp - close) / close * 100
    updated_orders = Enum.filter(order_book, &(&1["symboltoken"] == quote_data.token))

    socket =
      if updated_orders != [] do
        updated_orders
        |> Enum.filter(&(&1["ltp"] != new_ltp))
        |> Enum.reduce(socket, fn updated_order, socket ->
          {total_qty, _} = Integer.parse(updated_order["filledshares"])

          updated_order =
            updated_order
            |> Map.put_new("ltp", new_ltp)
            |> Map.put_new("close", close)
            |> Map.put_new("ltp_percent", ltp_percent)
            |> Map.put_new("is_gain_today?", close < new_ltp)
            |> Map.put_new("gains_or_loss", total_qty * (new_ltp - updated_order["averageprice"]))

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

  def handle_info(_, socket), do: {:noreply, socket}

  def handle_event(
        "select-holding",
        %{"exchange" => exchange, "symbol" => symbol_token, "selected-order-id" => order_id},
        %{assigns: %{token: token, order_book: order_book}} = socket
      ) do
    socket =
      with {:ok, %{"data" => %{"fetched" => [quote]}}} <-
             API.quote(token, exchange, [symbol_token]) do
        %{"ltp" => ltp, "close" => close} = quote
        ltp_percent = (ltp - close) / close * 100

        quote = Map.merge(quote, %{"ltp_percent" => ltp_percent, "is_gain_today?" => ltp > close})

        socket
        |> assign(quote: quote)
        |> assign(selected_order: Enum.find(order_book, &(&1["orderid"] == order_id)))
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
      with {:ok, %{"data" => %{"orderid" => order_id}}} <- API.cancel_order(token, order_id) do
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
         {:ok, %{"data" => order_book}} <- API.order_book(token) do
      order_book = Enum.sort(order_book || [], &(&1["orderid"] >= &2["orderid"]))

      socket
      |> assign(name: profile["name"])
      |> assign(funds: funds)
      |> stream_configure(:order_book, dom_id: &"order-#{&1["orderid"]}")
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
             order_book: order_book
           }
         } = socket
       ) do
    with {:ok, %{"data" => %{"fetched" => quotes}}} <-
           API.quote(token, "NSE", Enum.map(order_book, & &1["symboltoken"])) do
      Enum.each(quotes, fn quote_data ->
        send(
          self(),
          %{
            payload:
              Map.merge(quote_data, %{
                last_traded_price: quote_data["ltp"] * 100,
                token: quote_data["symbolToken"],
                close_price: quote_data["close"] * 100
              })
          }
        )
      end)
    end

    socket
  end
end
