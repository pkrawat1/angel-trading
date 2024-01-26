defmodule AngelTradingWeb.LiveComponents do
  defmacro __using__(_) do
    quote do
      alias AngelTradingWeb.LiveComponents.{
        CandleChart,
        QuoteModal
      }
    end
  end
end
