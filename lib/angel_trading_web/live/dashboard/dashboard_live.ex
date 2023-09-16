defmodule AngelTradingWeb.DashboardLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.Auth

  def mount(_params, %{"token" => token}, socket) do
    if connected?(socket) do
      :ok = AngelTradingWeb.Endpoint.subscribe("dashboard")
    end
    socket =
      with {:ok, %{"data" => holdings}} <- Auth.portfolio(token) do
        assign(socket, holdings: holdings |> Enum.sort(&(&2["tradingsymbol"] >= &1["tradingsymbol"])))
      else
        {:error, %{"message" => message}} ->
          put_flash(socket, :error, message)
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <legend class="text-4xl text-center">My Portfolio</legend>
    <ul class="bg-slate-50 p-4">
      <li
        :for={holding <- @holdings}
        class="hover:bg-blue-500 hover:ring-blue-500 hover:shadow-md group rounded-md m-3 p-3 bg-white ring-1 ring-slate-200 shadow-sm"
      >
        <dl class="items-center">
          <div>
            <dt class="sr-only">Title</dt>
            <dd class="flex group-hover:text-white font-semibold text-slate-900">
              <span>
                <%= holding["tradingsymbol"] |> String.split("-") |> List.first() %>
                <small class="text-xs text-blue-500">
                  <%= holding["exchange"] %>
                </small>
              </span>
            </dd>
          </div>
          <hr />
          <div>
            <dt class="sr-only">Invested Amount</dt>
            <dd class="text-xs group-hover:text-blue-200 flex justify-between">
              <span>
                Invested <%= Number.Currency.number_to_currency(
                  holding["realisedquantity"] * holding["averageprice"],
                  precision: 0
                ) %>
              </span>
              <span>
                Current <%= Number.Currency.number_to_currency(
                  holding["realisedquantity"] * holding["ltp"],
                  precision: 0
                ) %>
              </span>
            </dd>
          </div>
        </dl>
      </li>
    </ul>
    """
  end
end
