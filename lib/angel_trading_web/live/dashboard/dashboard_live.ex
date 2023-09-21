defmodule AngelTradingWeb.DashboardLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.API
  import Number.Currency, only: [number_to_currency: 1, number_to_currency: 2]

  def mount(_params, %{"token" => token}, socket) do
    if connected?(socket) do
      :ok = AngelTradingWeb.Endpoint.subscribe("dashboard")
    end

    socket =
      with {:ok, %{"data" => holdings}} <- API.portfolio(token),
           holdings <- formatted_holdings(holdings) do
        assign(socket,
          holdings: holdings |> Enum.sort(&(&2["tradingsymbol"] >= &1["tradingsymbol"])),
          total_invested: holdings |> Enum.map(& &1["invested"]) |> Enum.sum(),
          total_current: holdings |> Enum.map(& &1["current"]) |> Enum.sum(),
          total_overall_gain_or_loss:
            holdings |> Enum.map(& &1["overall_gain_or_loss"]) |> Enum.sum()
        )
      else
        {:error, %{"message" => message}} ->
          put_flash(socket, :error, message)
      end

    {:ok, socket}
  end

  def render(assigns) do
    IO.inspect(assigns[:holdings] |> List.first())

    ~H"""
    <legend class="text-4xl text-center">My Portfolio</legend>
    <ul class="bg-slate-50 p-4">
      <li
        :for={holding <- @holdings}
        class="hover:ring-blue-500 transition duration-300 hover:shadow-md group rounded-md m-3 p-3 bg-white ring-1 ring-slate-200 shadow-sm"
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
              <span class={[
                if(holding["in_overall_profit?"], do: "text-green-600", else: "text-red-600")
              ]}>
                <%= number_to_currency(holding["overall_gain_or_loss"]) %> (<%= holding[
                  "overall_gain_or_loss_percent"
                ]
                |> Float.floor(2) %>%)
              </span>
            </dd>
          </div>
          <div>
            <dd class="my-2 flex text-xs font-semibold text-slate-900 justify-between">
              <span>
                Avg <%= number_to_currency(holding["averageprice"]) %>
              </span>
              <span class={[if(holding["is_gain_today?"], do: "text-green-600", else: "text-red-600")]}>
                LTP <%= number_to_currency(holding["ltp"]) %> (<%= holding["ltp_percent"]
                |> Float.floor(2) %>%)
              </span>
            </dd>
          </div>
          <div>
            <dd class="my-2 flex text-xs font-semibold text-slate-900 justify-between">
              <span>
                Shares <%= holding["quantity"] %>
              </span>
              <span class={[if(holding["is_gain_today?"], do: "text-green-600", else: "text-red-600")]}>
                <%= if holding["is_gain_today?"], do: "Today's gain", else: "Today's loss" %> <%= number_to_currency(
                  holding[
                    "todays_profit_or_loss"
                  ]
                ) %> (<%= holding["todays_profit_or_loss_percent"]
                |> Float.floor(2) %>%)
              </span>
            </dd>
          </div>
          <hr />
          <div>
            <dt class="sr-only">Invested Amount</dt>
            <dd class="text-xs flex justify-between">
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

  # Using float calculation as of now. Since most of the data is coming from angel api.
  # I could add ex_money to manage calculations in decimal money format.
  def formatted_holdings(holdings) do
    Enum.map(holdings, fn %{
                            "authorisedquantity" => _,
                            "averageprice" => averageprice,
                            "close" => close,
                            "collateralquantity" => _,
                            "collateraltype" => _,
                            "exchange" => exchange,
                            "haircut" => _,
                            "isin" => _,
                            "ltp" => ltp,
                            "product" => _,
                            "profitandloss" => _,
                            "quantity" => quantity,
                            "realisedquantity" => _,
                            "symboltoken" => _,
                            "t1quantity" => _,
                            "tradingsymbol" => tradingsymbol
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
end
