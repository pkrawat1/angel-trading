defmodule AngelTradingWeb.DashboardLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.Auth

  def mount(_params, %{"token" => token}, socket) do
    socket =
      with {:ok, %{"data" => holdings}} <- Auth.portfolio(token) do
        assign(socket, holdings: holdings)
      else
        {:error, %{"message" => message}} ->
          put_flash(socket, :error, "Error loading portfolio.")
      end

    {:ok, socket}
  end

  def render(assigns) do
    IO.inspect(assigns)

    ~H"""
    <legend class="text-4xl text-center">My Portfolio</legend>
    <ul class="bg-slate-50 p-4 sm:px-8 sm:pt-6 sm:pb-8 lg:p-4 xl:px-8 xl:pt-6 xl:pb-8 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2 gap-4 text-sm leading-6">
      <li
        :for={holding <- @holdings}
        class="hover:bg-blue-500 hover:ring-blue-500 hover:shadow-md group rounded-md p-3 bg-white ring-1 ring-slate-200 shadow-sm"
      >
        <dl class="grid sm:block lg:grid xl:block grid-cols-2 grid-rows-2 items-center">
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
