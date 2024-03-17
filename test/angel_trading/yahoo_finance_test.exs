defmodule YahooFinanceTest do
  use ExUnit.Case
  doctest AngelTrading.YahooFinance

  test "search" do
    assert AngelTrading.YahooFinance.search("swan energe") == {:ok, []}
    assert AngelTrading.YahooFinance.search("swan energy") == {:ok, [
      %{
        symbol: "SWANENERGY.NS",
        __struct__: YQuoteItem,
        long_name: "Swan Energy Limited"
      }
    ]}
    assert AngelTrading.YahooFinance.search("sbin") == {:ok, [
      %{
        symbol: "SBIN.NS",
        __struct__: YQuoteItem,
        long_name: "State Bank of India"
      }
    ]}
  end
end
