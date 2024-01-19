defmodule AngelTradingWeb.LiveComponents.CandleChart do
  use AngelTradingWeb, :live_component

  def render(assigns) do
    ~H"""
    <div>
      <.candle_chart dataset={assigns[:dataset]} {@chart_config} />
    </div>
    """
  end

  def update(%{event: "update-chart", dataset: dataset}, socket) do
    {
      :ok,
      socket
      |> push_event("update-chart", %{dataset: dataset})
    }
  end

  def update(assigns, socket) do
    {
      :ok,
      socket
      |> assign(assigns)
    }
  end
end
