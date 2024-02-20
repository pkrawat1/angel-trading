defmodule AngelTradingWeb.DashboardLive do
  use AngelTradingWeb, :live_view

  alias AngelTrading.{Account, API}
  require Logger

  embed_templates "*"

  def mount(_params, %{"user_hash" => user_hash}, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Home")
     |> assign(:user_hash, user_hash)
     |> get_portfolio_data}
  end

  defp get_portfolio_data(socket) do
    client_codes =
      Account.get_client_codes(socket.assigns.user_hash)
      |> case do
        {:ok, %{body: data}} when is_map(data) -> Map.values(data)
        _ -> []
      end

    socket
    |> assign(:client_codes, client_codes)
  end

  def handle_info(
        {:subscribe_to_feed,
         %{
           client_code: client_code,
           symbol_tokens: symbol_tokens,
           token: token,
           feed_token: feed_token
         }},
        socket
      ) do
    socket_process = :"#{client_code}-quote-stream"

    subscribe_to_feed = fn ->
      WebSockex.send_frame(
        socket_process,
        {:text,
         Jason.encode!(%{
           correlationID: client_code,
           action: 1,
           params: %{
             mode: 3,
             tokenList: [
               %{
                 exchangeType: 1,
                 tokens: symbol_tokens
               }
             ]
           }
         })}
      )
    end

    with nil <- Process.whereis(socket_process),
         {:ok, pid} when is_pid(pid) <-
           API.socket(client_code, token, feed_token, "quote-stream-" <> client_code) do
      Logger.info("[Dashboard] web socket (#{socket_process}) started")

      subscribe_to_feed.()
    else
      pid when is_pid(pid) ->
        Logger.info(
          "[Dashboard] web socket (#{socket_process} #{inspect(pid)}) already established"
        )

        subscribe_to_feed.()

      e ->
        with {:ok, %{"data" => %{"fetched" => quotes}}} <-
               API.quote(token, "NSE", symbol_tokens) do
          Enum.each(quotes, fn quote_data ->
            send(
              self(),
              %{
                topic: "quote-stream-" <> client_code,
                payload:
                  Map.merge(quote_data, %{
                    last_traded_price: quote_data["ltp"] * 100,
                    token: quote_data["symbolToken"]
                  })
              }
            )
          end)
        end

        Logger.error("[Dashboard] Error connecting to web socket (#{socket_process})")
        IO.inspect(e)

        send(
          self(),
          {:subscribe_to_feed,
           %{
             client_code: client_code,
             symbol_tokens: symbol_tokens,
             token: token,
             feed_token: feed_token
           }}
        )
    end

    {:noreply, socket}
  end

  def handle_info(
        %{topic: "quote-stream-" <> client_code, payload: quote_data},
        socket
      ) do
    send_update(__MODULE__.Portfolio, id: client_code, quote_data: quote_data)
    {:noreply, socket}
  end
end
