defmodule AngelTradingWeb.LiveComponents.QuoteModal do
  use AngelTradingWeb, :live_component

  def render(assigns) do
    ~H"""
    <div>
      <.modal show id="buy-modal" on_cancel={@on_cancel}>
        <div class="text-xs md:text-sm uppercase -m-10 md:-m-8">
          <.header>
            <%= @quote["tradingSymbol"] |> String.split("-") |> List.first() %>
            <small class="text-xs text-blue-500">
              <%= @quote["exchange"] %>
            </small>
            <br />
            <div class="text-xs md:text-sm">
              <span :if={@quote["is_gain_today?"]} class="text-green-600">
                <%= number_to_currency(@quote["ltp"]) %>
                <.icon name="hero-arrow-up" />
              </span>
              <span :if={!@quote["is_gain_today?"]} class="text-red-600">
                <%= number_to_currency(@quote["ltp"]) %>
                <.icon name="hero-arrow-down" />
              </span>
              <span>
                <%= (@quote["ltp"] - @quote["close"]) |> Float.floor(2) %> (<%= @quote["ltp_percent"]
                |> Float.floor(2) %>%)
              </span>
            </div>
          </.header>
          <section class="my-5">
            <div class="flex justify-between text-center">
              <span>
                Open <br />
                <b><%= @quote["open"] %></b>
              </span>
              <span>
                High <br />
                <b><%= @quote["high"] %></b>
              </span>
              <span>
                Low <br />
                <b><%= @quote["low"] %></b>
              </span>
              <span>
                Close <br />
                <b><%= @quote["close"] %></b>
              </span>
            </div>
            <div class="grid grid-cols-2 gap-4 my-2">
              <table class="table w-full">
                <thead class="border-y">
                  <th class="text-left">Qty</th>
                  <th class="text-right">Buy Price</th>
                </thead>
                <tbody>
                  <tr :for={buy <- @quote["depth"]["buy"]}>
                    <td><%= buy["quantity"] %></td>
                    <td class="text-right text-green-600"><%= buy["price"] %></td>
                  </tr>
                  <tr class="border-y">
                    <td><%= @quote["totBuyQuan"] %></td>
                    <td class="text-right">Total</td>
                  </tr>
                </tbody>
              </table>
              <table class="table w-full">
                <thead class="border-y">
                  <th class="text-left">Sell Price</th>
                  <th class="text-right">Qty</th>
                </thead>
                <tbody>
                  <tr :for={sell <- @quote["depth"]["sell"]}>
                    <td class="text-left text-red-600"><%= sell["price"] %></td>
                    <td class="text-right"><%= sell["quantity"] %></td>
                  </tr>
                  <tr class="border-y">
                    <td>Total</td>
                    <td class="text-right">
                      <%= @quote["totSellQuan"] %>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <.live_component
              :if={assigns[:candle_data]}
              id="quote-chart-wrapper"
              module={CandleChart}
              dataset={@candle_data}
              chart_config={
                %{
                  id: "quote-chart-" <> @quote["symbolToken"],
                  class: "h-[30vh] -mr-2.5 mt-5 -mb-1"
                }
              }
            />
          </section>
          <.render_place_order_actions :if={!assigns[:selected_order]} {assigns} />
          <.render_modify_order_actions :if={assigns[:selected_order]} {assigns} />
        </div>
      </.modal>
    </div>
    """
  end

  def render_place_order_actions(assigns) do
    ~H"""
    <section id="order-place-actions">
      <div class="w-full inline-flex rounded-md text-center" role="group">
        <% order_params = %{
          symbol_token: @quote["symbolToken"],
          exchange: @quote["exchange"],
          transaction_type: "BUY",
          trading_symbol: @quote["tradingSymbol"]
        } %>
        <.link
          navigate={~p"/client/#{@client_code}/order/new?#{order_params}"}
          class="w-1/2 px-4 py-2 text-white bg-green-600 rounded-s-lg focus-visible:outline-none"
        >
          BUY
        </.link>
        <.link
          navigate={
            ~p[/client/#{@client_code}/order/new?#{%{order_params | transaction_type: "SELL"}}]
          }
          class="w-1/2 px-4 py-2 text-white bg-red-600 rounded-e-lg focus-visible:outline-none"
        >
          SELL
        </.link>
      </div>
    </section>
    """
  end

  def render_modify_order_actions(%{selected_order: %{"status" => status}} = assigns)
      when status not in ["open", "pending"],
      do: render_place_order_actions(assigns)

  def render_modify_order_actions(assigns) do
    ~H"""
    <section id="modify-order-actions bottom-0">
      <div class="w-full inline-flex rounded-md text-center" role="group">
        <% order_params = %{
          symbol_token: @quote["symbolToken"],
          exchange: @quote["exchange"],
          transaction_type: @selected_order["transactiontype"],
          trading_symbol: @quote["tradingSymbol"],
          order_id: @selected_order["orderid"],
          order_type: @selected_order["ordertype"],
          price: @selected_order["price"],
          quantity: @selected_order["quantity"]
        } %>
        <.link
          data-confirm="Are you sure?"
          phx-click="cancel-order"
          phx-value-id={@selected_order["orderid"]}
          class="w-1/2 px-4 py-2 text-white bg-red-600 border border-red-200 rounded-s-lg focus-visible:outline-none"
        >
          Cancel
        </.link>
        <.link
          navigate={~p"/client/#{@client_code}/order/edit?#{order_params}"}
          class="w-1/2 px-4 py-2 text-white bg-blue-600 border border-blue-200 rounded-e-lg focus-visible:outline-none"
        >
          Modify
        </.link>
      </div>
    </section>
    """
  end
end
