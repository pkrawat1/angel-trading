defmodule AngelTradingWeb.DashboardLive do
  use AngelTradingWeb, :live_view

  def mount(_params, session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    Dashboard
    """
  end
end
