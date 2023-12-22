defmodule AngelTradingWeb.WatchlistLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.{Account, API, Utils}
  require Logger

  def mount(%{"client_code" => client_code}, %{"user_hash" => user_hash}, socket) do
    socket =
      with {:ok, %{body: %{"clients" => clients} = user}} <-
             Account.get_user(user_hash),
           user_clients <- Map.values(clients),
           {:valid_client, true} <- {:valid_client, client_code in user_clients},
           {:ok, %{body: data}} when is_binary(data) <- Account.get_client(client_code),
           {:ok, %{token: token, feed_token: feed_token}} <- Utils.decrypt(:client_tokens, data) do
        if connected?(socket) do
          :timer.send_interval(2000, self(), :subscribe_to_feed)
          :ok = AngelTradingWeb.Endpoint.subscribe("portfolio-for-#{client_code}")
        end

        watchlist = user["watchlist"] || []

        socket
        |> assign(
          token: token,
          feed_token: feed_token,
          client_code: client_code,
          watchlist: watchlist,
          quote: nil,
          order: %{type: "LIMIT", price: nil, quantity: nil}
        )
        |> stream_configure(:watchlist, dom_id: &"watchlist-quote-#{&1["symboltoken"]}")
        |> stream(:watchlist, watchlist)
      else
        e ->
          IO.inspect(e)

          socket
          |> put_flash(:error, "Invalid client")
          |> push_navigate(to: "/")
      end

    {:ok,
     socket
     |> assign(:page_title, "Watchlist")
     |> assign(:user_hash, user_hash)
     |> assign(:token_list, [])}
  end

  def handle_params(
        _,
        _,
        %{assigns: %{live_action: :quote, quote: quote, client_code: client_code}} = socket
      )
      when is_nil(quote),
      do: {:noreply, push_patch(socket, to: ~p"/client/#{client_code}/watchlist")}

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
        %{payload: new_quote},
        %{assigns: %{live_action: :quote, quote: quote}} = socket
      ) do
    socket =
      if(new_quote.token == quote["symbolToken"]) do
        {_, socket} =
          handle_event(
            "select-holding",
            %{
              "exchange" => quote["exchange"],
              "symbol" => new_quote.token
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
        %{assigns: %{watchlist: watchlist}} = socket
      ) do
    new_ltp = quote_data.last_traded_price / 100
    close = quote_data.close_price / 100
    ltp_percent = (new_ltp - close) / close * 100

    updated_watchlist_quote =
      Enum.find(watchlist, &(&1["symboltoken"] == quote_data.token))

    socket =
      if updated_watchlist_quote && updated_watchlist_quote["ltp"] != new_ltp do
        updated_watchlist_quote =
          updated_watchlist_quote
          |> Map.put_new("ltp", new_ltp)
          |> Map.put_new("close", close)
          |> Map.put_new("ltp_percent", ltp_percent)
          |> Map.put_new("is_gain_today?", close < new_ltp)

        socket
        |> stream_insert(
          :watchlist,
          updated_watchlist_quote,
          at: -1
        )
      end || socket

    {:noreply, socket}
  end

  def handle_event("search", %{"search" => query}, %{assigns: %{token: token}} = socket) do
    token_list =
      with true <- bit_size(query) > 0,
           {:ok, %{"data" => token_list}} <- API.search_token(token, "NSE", query) do
        token_list
        |> Enum.filter(&String.ends_with?(&1["tradingsymbol"], "-EQ"))
      else
        _ -> []
      end

    {:noreply, assign(socket, :token_list, token_list)}
  end

  def handle_event(
        "toggle-token-watchlist",
        %{"token" => token},
        %{assigns: %{watchlist: watchlist, token_list: token_list, user_hash: user_hash}} = socket
      ) do
    new_watch = Enum.find(token_list, &(&1["symboltoken"] == token))
    token_exist? = watchlist |> Enum.find(&(&1["symboltoken"] == token))

    watchlist =
      if token_exist? do
        watchlist
        |> Enum.filter(&(&1["symboltoken"] != token))
      else
        [new_watch | watchlist]
      end

    socket =
      case Account.update_watchlist(user_hash, watchlist) do
        :ok ->
          if token_exist? do
            stream_delete(socket, :watchlist, new_watch)
          else
            stream_insert(
              socket,
              :watchlist,
              new_watch,
              at: -1
            )
          end
          |> assign(watchlist: watchlist)
          |> subscribe_to_quote_feed()

        _ ->
          socket
          |> put_flash(:error, "Failed to update watchlist.")
      end

    {:noreply, socket}
  end

  def handle_event(
        "select-holding",
        %{"exchange" => exchange, "symbol" => symbol_token},
        %{assigns: %{token: token}} = socket
      ) do
    socket =
      with {:ok, %{"data" => %{"fetched" => [quote]}}} <- API.quote(token, exchange, symbol_token) do
        %{"ltp" => ltp, "close" => close} = quote
        ltp_percent = (ltp - close) / close * 100

        quote = Map.merge(quote, %{"ltp_percent" => ltp_percent, "is_gain_today?" => ltp > close})

        socket
        |> assign(quote: quote)
      else
        _ ->
          socket
          |> assign(quote: nil)
          |> put_flash(:error, "[Quote] : Failed to fetch quote")
      end

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
        %{assigns: %{quote: quote, order: order, token: token, client_code: client_code}} = socket
      ) do
    socket =
      with {:ok, %{"data" => %{"orderid" => order_id}}} <-
             API.place_order(token, %{
               exchange: quote["exchange"],
               trading_symbol: quote["tradingSymbol"],
               symbol_token: quote["symbolToken"],
               quantity: quantity,
               transaction_type: "BUY",
               order_type: order.type,
               variety: "NORMAL",
               product_type: "DELIVERY",
               price: price
             }) do
        socket
        |> push_patch(to: ~p"/client/#{client_code}/watchlist")
        |> put_flash(:info, "Order[#{order_id}] placed successfully")
        |> assign(order: %{type: "LIMIT", price: nil, quantity: nil})
      else
        e ->
          Logger.error("[Watchlist][Order] Error placing order")
          IO.inspect(e)

          socket
          |> push_patch(to: ~p"/client/#{client_code}/watchlist")
          |> put_flash(:error, "Failed to place order.")
      end

    {:noreply, socket}
  end

  defp subscribe_to_quote_feed(
         %{assigns: %{client_code: client_code, watchlist: watchlist}} = socket
       ) do
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
               tokens: Enum.map(watchlist, & &1["symboltoken"])
             }
           ]
         }
       })}
    )

    socket
  end
end
