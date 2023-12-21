defmodule AngelTradingWeb.Components do
  defmacro __using__(_) do
    quote do
      import AngelTradingWeb.CoreComponents

      import AngelTradingWeb.Components.{
        BottomNav
      }
    end
  end
end
