defmodule AngelTradingWeb.DashboardLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.API
  import Number.Currency, only: [number_to_currency: 1, number_to_currency: 2]

  def mount(
        _params,
        %{"token" => token, "client_code" => client_code, "feed_token" => feed_token},
        socket
      ) do
    if connected?(socket) do
      :ok = AngelTradingWeb.Endpoint.subscribe("portfolio-for-#{client_code}")
      :timer.send_interval(1000, self(), :tick)
    end

    {:ok,
     socket
     |> assign(:token, token)
     |> assign(:client_code, client_code)
     |> assign(:feed_token, feed_token)
     |> get_portfolio_data()}
  end

  def render(assigns) do
    # IO.inspect(assigns[:holdings] |> List.first())

    ~H"""
    <div class="block w-full p-6 my-5 border rounded-lg shadow hover:shadow-md capitalize text-white bg-gray-800 border-gray-700 hover:bg-gray-700">
      <h5 class="text-center mb-5 text-2xl font-bold tracking-tight">
        <%= String.downcase(@name) %>
      </h5>
      <div class="text-xl">
        <%= number_to_currency(@total_current, precision: 0) %> <br />
        <small :if={@in_overall_profit?}>
          <.icon name="hero-arrow-up w-4 h-4 text-green-600" /> Overall gain
          <span class="text-green-600">
            <%= number_to_currency(@total_overall_gain_or_loss, precision: 0) %> (<%= Float.floor(
              @total_overall_gain_or_loss_percent,
              2
            ) %> %)
          </span>
        </small>
        <small :if={!@in_overall_profit?}>
          <.icon name="hero-arrow-down text-red-600" /> Overall loss
          <span class="text-red-600">
            <%= @total_overall_gain_or_loss |> abs() |> number_to_currency() %> (<%= Float.floor(
              @total_overall_gain_or_loss_percent,
              2
            ) %>%)
          </span>
        </small>
      </div>
      <div class="text-xl mt-5 flex justify-between">
        <small>
          Invested Value<br />
          <%= number_to_currency(@total_invested, precision: 0) %> <br />
        </small>
        <small :if={@in_overall_profit_today?}>
          <.icon name="hero-arrow-up w-4 h-4 text-green-600" /> Today's gain<br />
          <span class="text-green-600">
            <%= number_to_currency(@total_todays_gain_or_loss, precision: 0) %> (<%= Float.floor(
              @total_todays_gain_or_loss_percent,
              2
            ) %>%)
          </span>
        </small>
        <small :if={!@in_overall_profit_today?}>
          <.icon name="hero-arrow-down w-4 h-4 text-red-600" /> Today's Loss<br />
          <span class="text-red-600">
            <%= @total_todays_gain_or_loss |> abs() |> number_to_currency(precision: 0) %> (<%= Float.floor(
              @total_todays_gain_or_loss_percent,
              2
            ) %>%)
          </span>
        </small>
      </div>
    </div>

    <ul>
      <li
        :for={holding <- @holdings}
        class="hover:ring-blue-500 transition duration-300 hover:shadow-md group rounded-md my-3 p-3 bg-white ring-1 ring-slate-200 shadow"
      >
        <dl class="items-center">
          <div>
            <dd class="flex font-semibold text-slate-900 justify-between">
              <span>
                <%= holding["tradingsymbol"] |> String.split("-") |> List.first() %>
                <small class="text-xs text-blue-500">
                  <%= holding["exchange"] %>
                </small>
              </span>
              <div>
                <span :if={holding["in_overall_profit?"]} class="text-green-600">
                  <%= number_to_currency(holding["overall_gain_or_loss"]) %>
                </span>
                <span :if={!holding["in_overall_profit?"]} class="text-red-600">
                  <%= holding["overall_gain_or_loss"] |> abs() |> number_to_currency() %>
                </span>
                <small>
                  (<%= holding["overall_gain_or_loss_percent"] |> Float.floor(2) %>%)
                </small>
              </div>
            </dd>
          </div>
          <div>
            <dd class="my-2 flex text-xs font-semibold text-slate-900 justify-between">
              <span>
                Avg <%= number_to_currency(holding["averageprice"]) %>
              </span>
              <div>
                <span :if={holding["is_gain_today?"]} class="text-green-600">
                  LTP <%= number_to_currency(holding["ltp"]) %>
                </span>
                <span :if={!holding["is_gain_today?"]} class="text-red-600">
                  LTP <%= number_to_currency(holding["ltp"]) %>
                </span>
                <span>
                  (<%= holding["ltp_percent"]
                  |> Float.floor(2) %>%)
                </span>
              </div>
            </dd>
          </div>
          <div>
            <dd class="my-2 flex text-xs font-semibold text-slate-900 justify-between">
              <span>
                Shares <%= holding["quantity"] %>
              </span>
              <div>
                <span :if={holding["is_gain_today?"]} class="text-green-600">
                  Today's gain <%= number_to_currency(
                    holding[
                      "todays_profit_or_loss"
                    ]
                  ) %>
                </span>
                <span :if={!holding["is_gain_today?"]} class="text-red-600">
                  Today's Loss <%= holding["todays_profit_or_loss"] |> abs() |> number_to_currency() %>
                </span>
                <span>
                  (<%= holding["todays_profit_or_loss_percent"] |> Float.floor(2) %>%)
                </span>
              </div>
            </dd>
          </div>
          <hr />
          <div>
            <dt class="sr-only">Invested Amount</dt>
            <dd class="text-xs flex justify-between pt-2">
              <span>
                Invested <%= number_to_currency(holding["invested"], precision: 0) %>
              </span>
              <span>
                Current <%= number_to_currency(holding["current"], precision: 0) %>
              </span>
            </dd>
          </div>
        </dl>
      </li>
    </ul>
    """
  end

  def handle_info(
        :tick,
        %{
          assigns: %{
            client_code: client_code,
            token: token,
            feed_token: feed_token
          }
        } = socket
      ) do
    socket_process = :"#{client_code}"

    unless Process.whereis(socket_process) do
      AngelTrading.API.socket(client_code, token, feed_token)
    end

    WebSockex.send_frame(
      socket_process,
      {:text,
       Jason.encode!(%{
         correlationID: "abcde12345",
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

    {:noreply, socket}
  end

  def handle_info(%{payload: quote_data}, %{assigns: %{holdings: holdings}} = socket) do
    holdings =
      holdings
      |> Enum.map(fn holding ->
        if holding["symboltoken"] == quote_data.token do
          %{holding | "ltp" => quote_data.last_traded_price / 100}
        else
          holding
        end
      end)
      |> formatted_holdings()

    {:noreply,
     socket
     |> calculated_overview(holdings)
     |> assign(holdings: Enum.sort(holdings, &(&2["tradingsymbol"] >= &1["tradingsymbol"])))}
  end

  defp get_portfolio_data(%{assigns: %{token: token}} = socket) do
    with {:ok, %{"data" => profile}} <- API.profile(token),
         {:ok, %{"data" => holdings}} <- API.portfolio(token) do
      holdings = formatted_holdings(holdings)

      socket
      |> calculated_overview(holdings)
      |> assign(
        holdings: Enum.sort(holdings, &(&2["tradingsymbol"] >= &1["tradingsymbol"])),
        name: profile["name"]
      )
    else
      {:error, %{"message" => message}} ->
        put_flash(socket, :error, message)
    end
  end

  # Using float calculation as of now. Since most of the data is coming from angel api.
  # I could add ex_money to manage calculations in decimal money format.
  defp formatted_holdings(holdings) do
    Enum.map(holdings, fn %{
                            "authorisedquantity" => _,
                            "averageprice" => averageprice,
                            "close" => close,
                            "collateralquantity" => _,
                            "collateraltype" => _,
                            "exchange" => _,
                            "haircut" => _,
                            "isin" => _,
                            "ltp" => ltp,
                            "product" => _,
                            "profitandloss" => _,
                            "quantity" => quantity,
                            "realisedquantity" => _,
                            "symboltoken" => _,
                            "t1quantity" => _,
                            "tradingsymbol" => _
                          } = holding ->
      invested = quantity * averageprice
      current = quantity * ltp
      overall_gain_or_loss = quantity * (ltp - averageprice)
      overall_gain_or_loss_percent = overall_gain_or_loss / invested * 100
      todays_profit_or_loss = quantity * (ltp - close)
      todays_profit_or_loss_percent = todays_profit_or_loss / invested * 100
      ltp_percent = (ltp - close) / close * 100

      Map.merge(holding, %{
        "invested" => invested,
        "current" => current,
        "in_overall_profit?" => current > invested,
        "is_gain_today?" => ltp > close,
        "overall_gain_or_loss" => overall_gain_or_loss,
        "overall_gain_or_loss_percent" => overall_gain_or_loss_percent,
        "todays_profit_or_loss" => todays_profit_or_loss,
        "todays_profit_or_loss_percent" => todays_profit_or_loss_percent,
        "ltp_percent" => ltp_percent
      })
    end)
  end

  defp calculated_overview(socket, holdings) do
    total_invested = holdings |> Enum.map(& &1["invested"]) |> Enum.sum()
    total_overall_gain_or_loss = holdings |> Enum.map(& &1["overall_gain_or_loss"]) |> Enum.sum()
    total_todays_gain_or_loss = holdings |> Enum.map(& &1["todays_profit_or_loss"]) |> Enum.sum()

    assign(socket,
      holdings: holdings |> Enum.sort(&(&2["tradingsymbol"] >= &1["tradingsymbol"])),
      total_invested: total_invested,
      total_current: holdings |> Enum.map(& &1["current"]) |> Enum.sum(),
      total_overall_gain_or_loss: total_overall_gain_or_loss,
      total_todays_gain_or_loss: total_todays_gain_or_loss,
      in_overall_profit_today?: total_todays_gain_or_loss > 0,
      in_overall_profit?: total_overall_gain_or_loss > 0,
      total_overall_gain_or_loss_percent: total_overall_gain_or_loss / total_invested * 100,
      total_todays_gain_or_loss_percent: total_todays_gain_or_loss / total_invested * 100
    )
  end
end
