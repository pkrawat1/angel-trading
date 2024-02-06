defmodule AngelTradingWeb.DashboardLive do
  use AngelTradingWeb, :live_view

  alias AngelTrading.{Account, API, Utils}
  require Logger

  embed_templates "*"

  def mount(_params, %{"user_hash" => user_hash}, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:user_hash, user_hash)
     |> get_portfolio_data}
  end

  defp get_portfolio_data(socket) do
    live_view_pid = self()

    client_codes =
      Account.get_client_codes(socket.assigns.user_hash)
      |> case do
        {:ok, %{body: data}} when is_map(data) -> Map.values(data)
        _ -> []
      end
      |> Enum.map(fn client_code ->
        :ok = Phoenix.PubSub.subscribe(AngelTrading.PubSub, "quote-stream-#{client_code}")
        client_code
      end)

    async_fn = fn ->
      {:ok,
       %{
         clients:
           client_codes
           |> Task.async_stream(
             fn client_code ->
               with {:ok, %{body: data}} when is_binary(data) <- Account.get_client(client_code),
                    {:ok, %{token: token} = client} <- Utils.decrypt(:client_tokens, data),
                    {:profile, {:ok, %{"data" => profile}}} <- {:profile, API.profile(token)},
                    {:portfolio, {:ok, %{"data" => holdings}}} <-
                      {:portfolio, API.portfolio(token)},
                    {:funds, {:ok, %{"data" => funds}}} <- {:funds, API.funds(token)},
                    {_, dis_status} <-
                      API.verify_dis(token, holdings |> List.first() |> Map.get("isin", "")) do
                 Process.send_after(live_view_pid, {:subscribe_to_feed, client_code}, 500)
                 :timer.send_interval(30000, live_view_pid, {:subscribe_to_feed, client_code})

                 Map.merge(client, %{
                   id: client.client_code,
                   holdings: holdings,
                   profile: profile,
                   funds: funds,
                   dis_status: Map.get(dis_status || %{}, "errorcode", nil) == "AG1000"
                 })
               else
                 e ->
                   e
               end
             end,
             max_concurrency: 4,
             on_timeout: :kill_task
           )
           |> Enum.map(&elem(&1, 1))
           |> Enum.filter(fn client ->
             case is_map(client) do
               false ->
                 Logger.error("[Dashboard] Unable to fetch data")
                 IO.inspect(client)
                 false

               _ ->
                 true
             end
           end)
       }}
    end

    socket
    |> assign_async(:clients, async_fn)
    |> assign(:client_codes, client_codes)
  end

  def handle_info(
        {:subscribe_to_feed, client_code},
        %{assigns: %{clients: %{ok?: true} = clients}} = socket
      ) do
    clients
    |> Map.get(:result)
    |> Enum.filter(&(&1.client_code == client_code))
    |> Enum.each(fn %{
                      client_code: client_code,
                      token: token,
                      feed_token: feed_token,
                      holdings: holdings
                    } ->
      socket_process = :"#{client_code}"

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
                   tokens: Enum.map(holdings, & &1["symboltoken"])
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
                 API.quote(token, "NSE", Enum.map(holdings, & &1["symboltoken"])) do
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
          send(self(), {:subscribe_to_feed, client_code})
      end
    end)

    {:noreply, socket}
  end

  def handle_info({:subscribe_to_feed, _}, socket), do: {:noreply, socket}

  def handle_info(
        %{topic: "quote-stream-" <> client_code, payload: quote_data},
        %{assigns: %{clients: %{ok?: true, result: clients}}} = socket
      ) do
    client = Enum.find(clients, &(&1.client_code == client_code))

    if client do
      new_ltp = quote_data.last_traded_price

      updated_holding = Enum.find(client.holdings, &(&1["symboltoken"] == quote_data.token))

      updated_client =
        if updated_holding && updated_holding["ltp"] != new_ltp do
          updated_holding =
            [%{updated_holding | "ltp" => new_ltp}]
            |> Utils.formatted_holdings()
            |> List.first()

          %{
            client
            | holdings:
                client.holdings
                |> Enum.map(fn holding ->
                  if holding["symboltoken"] == quote_data.token do
                    updated_holding
                  else
                    holding
                  end
                end)
          }
        else
          client
        end

      {:noreply,
       assign_async(socket, :clients, fn ->
         {:ok,
          %{
            clients:
              Enum.map(clients, fn client ->
                if client.client_code == updated_client.client_code do
                  updated_client
                else
                  client
                end
              end)
          }}
       end)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        %{topic: "quote-stream-" <> _},
        socket
      ),
      do: {:noreply, socket}

  def calculated_overview(client) do
    client
    |> Map.get(:holdings)
    |> Utils.formatted_holdings()
    |> Utils.calculated_overview()
  end
end
