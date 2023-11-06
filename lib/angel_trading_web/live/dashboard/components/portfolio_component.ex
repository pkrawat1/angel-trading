defmodule AngelTradingWeb.Dashboard.Components.PortfolioComponent do
  use AngelTradingWeb, :live_component
  alias AngelTrading.{API, Utils}

  def update(assigns, socket) do
    :ok = AngelTradingWeb.Endpoint.subscribe("portfolio-for-#{assigns.client_code}")
    {:ok, socket |> assign(assigns) |> get_portfolio_data()}
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
      |> Utils.formatted_holdings()

    updated_holding = Enum.find(holdings, &(&1["symboltoken"] == quote_data.token))

    socket =
      if(updated_holding) do
        stream_insert(socket, :holdings, updated_holding, at: -1)
      else
        socket
      end

    {:noreply,
     socket
     |> Utils.calculated_overview(holdings)}
  end

  defp get_portfolio_data(%{assigns: %{token: token}} = socket) do
    with {:ok, %{"data" => profile}} <- API.profile(token),
         {:ok, %{"data" => holdings}} <- API.portfolio(token) do
      holdings = Utils.formatted_holdings(holdings)

      socket
      |> Utils.calculated_overview(holdings)
      |> assign(name: profile["name"])
    else
      {:error, %{"message" => message}} ->
        put_flash(socket, :error, message)
    end
  end
end
