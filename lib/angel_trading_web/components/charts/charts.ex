defmodule AngelTradingWeb.Components.Charts do
  @moduledoc """
  Holds the chart components
  """
  use Phoenix.Component

  attr :id, :string, required: true
  attr :width, :integer, default: nil
  attr :height, :integer, default: nil
  attr :dataset, :list, default: []
  attr :class, :string, default: ""

  def candle_chart(assigns) do
    ~H"""
    <div
      class={@class}
      id={@id}
      phx-hook="CandleChart"
      data-config={
        Jason.encode!(
          trim(%{
            height: @height,
            width: @width
          })
        )
      }
      data-series={Jason.encode!(@dataset)}
    />
    """
  end

  defp trim(map) do
    Map.reject(map, fn {_key, val} -> is_nil(val) || val == "" end)
  end
end
