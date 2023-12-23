defmodule AngelTradingWeb.OrderLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.{Account, API, Utils}
  require Logger

  def mount(
        %{
          "client_code" => client_code,
          "symbol_token" => symbol_token,
          "exchange" => exchange,
          "transaction_type" => transaction_type
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
        |> assign(:symbol_token, symbol_token)
        |> assign(:quote, nil)
        |> assign(:order, %{
          type: "LIMIT",
          price: nil,
          quantity: nil,
          transaction_type: transaction_type,
          exchange: exchange,
          symbol_token: symbol_token
        })
        |> get_profile_data()
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
        socket
      ) do
    IO.inspect(new_quote)
    {:noreply, assign(socket, quote: new_quote)}
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
               tokens: order.symbol_token
             }
           ]
         }
       })}
    )

    socket
  end
end
