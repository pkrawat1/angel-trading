defmodule AngelTradingWeb.WatchlistLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.{Account, API, Utils}
  require Logger

  def mount(_params, %{"user_hash" => user_hash}, socket) do
    if connected?(socket) do
      :timer.send_interval(2000, self(), :subscribe_to_feed)
    end

    socket =
      with {:ok, %{body: %{"client_code" => client_code} = user}} <-
             Account.get_user(user_hash),
           {:ok, %{body: data}} when is_binary(data) <- Account.get_client(client_code),
           {:ok, %{token: token, feed_token: feed_token}} <- Utils.decrypt(:client_tokens, data),
           :ok <- AngelTradingWeb.Endpoint.subscribe("portfolio-for-#{client_code}") do
        watchlist = user["watchlist"] || []

        socket
        |> assign(
          token: token,
          feed_token: feed_token,
          client_code: client_code,
          watchlist: watchlist
        )
        |> stream_configure(:watchlist, dom_id: &"watchlist-quote-#{&1["symboltoken"]}")
        |> stream(:watchlist, watchlist)
      else
        _ ->
          socket
          |> put_flash(:error, "Unable to fetch data")
          |> push_navigate(to: "/")
      end

    {:ok,
     socket
     |> assign(:page_title, "Watchlist")
     |> assign(:user_hash, user_hash)
     |> assign(:token_list, [])}
  end

  def handle_info(
        :subscribe_to_feed,
        %{
          assigns: %{
            client_code: client_code,
            token: token,
            feed_token: feed_token,
            watchlist: watchlist
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
        %{assigns: %{watchlist: watchlist}} = socket
      ) do
    new_ltp = quote_data.last_traded_price / 100

    updated_watchlist_quote =
      Enum.find(watchlist, &(&1["symboltoken"] == quote_data.token))

    socket =
      if updated_watchlist_quote && updated_watchlist_quote["ltp"] != new_ltp do
        updated_watchlist_quote =
          updated_watchlist_quote
          |> Map.put_new("ltp", new_ltp)

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
