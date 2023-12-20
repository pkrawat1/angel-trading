defmodule AngelTradingWeb.OrdersLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.{Account, API, Utils}
  import Number.Currency, only: [number_to_currency: 1]
  require Logger

  def mount(%{"client_code" => client_code}, %{"user_hash" => user_hash}, socket) do
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
        |> assign(:page_title, "Orders")
        |> assign(:token, token)
        |> assign(:client_code, client_code)
        |> assign(:feed_token, feed_token)
        |> assign(:refresh_token, refresh_token)
        |> get_order_data()
      else
        _ ->
          socket
          |> put_flash(:error, "Invalid client")
          |> push_navigate(to: "/")
      end

    {:ok, socket}
  end

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
                 tokens: Enum.map(socket.assigns.order_book, & &1["symboltoken"])
               }
             ]
           }
         })}
      )
    else
      pid when is_pid(pid) ->
        Logger.info("[Order] web socket (#{socket_process} #{inspect(pid)}) already established")

      e ->
        Logger.error("[Order] Error connecting to web socket (#{socket_process})")
        IO.inspect(e)
    end

    {:noreply, socket}
  end

  def handle_info(
        %{payload: quote_data},
        %{assigns: %{order_book: order_book}} = socket
      ) do
    new_ltp = quote_data.last_traded_price / 100
    close = quote_data.close_price / 100
    ltp_percent = (new_ltp - close) / close * 100
    updated_order = Enum.find(order_book, &(&1["symboltoken"] == quote_data.token))
    {total_qty, _} = Integer.parse(updated_order["filledshares"])

    socket =
      if updated_order && updated_order["ltp"] != new_ltp do
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
      end || socket

    {:noreply, socket}
  end

  defp get_order_data(%{assigns: %{token: token}} = socket) do
    with {:ok, %{"data" => profile}} <- API.profile(token),
         {:ok, %{"data" => funds}} <- API.funds(token),
         {:ok, %{"data" => order_book}} <- API.order_book(token) do
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
end
