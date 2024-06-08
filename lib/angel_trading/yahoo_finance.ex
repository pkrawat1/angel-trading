defmodule AngelTrading.YahooFinance do
  @moduledoc """
  This module provides an interface to interact with Yahoo Finance's API for retrieving stock data.
  """

  use Rustler, otp_app: :angel_trading, crate: "yahoo_finance"

  # When your NIF is loaded, it will override this function.
  @doc """
  Searches for a company by name and returns stock data.

  ## Parameters

    - `company_name`: A string representing the name of the company.

  ## Returns

    - `{:ok, []}` if no matching company is found.
    - `{:ok, quote_items}` where `quote_items` is a list of `YQuoteItem` structs representing the matching companies.

  ## Examples

      iex> AngelTrading.YahooFinance.search("swan energe")
      {:ok, []}

      iex> AngelTrading.YahooFinance.search("swan energy")
      {:ok, [
        %{
          symbol: "SWANENERGY.NS",
          __struct__: YQuoteItem,
          long_name: "Swan Energy Limited"
        }
      ]}

      iex> AngelTrading.YahooFinance.search("")
      {:error, "fetching the data from yahoo! finance failed"}

  """
  def search(_company_name), do: :erlang.nif_error(:nif_not_loaded)
end
