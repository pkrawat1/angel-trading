defmodule AngelTrading.Client do
  @moduledoc """
  Module responsible for handling client-related functions, such as fetching
  client portfolio information, searching for stocks, and retrieving candle data.
  """
  alias AngelTrading.{API, Utils, YahooFinance}

  @doc """
  Returns the client's portfolio information as a map.

  ## Examples

      iex> AngelTrading.Client.get_client_portfolio_info("valid_token")
      {:ok, %{profile: %{name: "John Doe"}, holdings: [...], funds: %{net: 100_000.0}}}

      iex> AngelTrading.Client.get_client_portfolio_info("invalid_token")
      {:error, :unauthorized}

  """
  @spec get_client_portfolio_info(binary) :: {:ok, map} | {:error, atom}
  def get_client_portfolio_info(token) do
    with {:profile, {:ok, %{"data" => profile}}} <- {:profile, API.profile(token)},
         {:portfolio, {:ok, %{"data" => holdings}}} <- {:portfolio, API.portfolio(token)},
         {:funds, {:ok, %{"data" => funds}}} <- {:funds, API.funds(token)} do
      {:ok,
       %{
         profile: profile,
         holdings:
           holdings
           |> Utils.formatted_holdings()
           |> Utils.calculated_overview(),
         funds: funds
       }}
    else
      {:profile, {:error, _}} -> {:error, :unauthorized}
      {:portfolio, {:error, _}} -> {:error, :unauthorized}
      {:funds, {:error, _}} -> {:error, :unauthorized}
      _ -> {:error, :internal_server_error}
    end
  end

  @doc """
  Searches for stock details based on the provided name.

  ## Parameters

    - name: Stock name to search for.
    - token: Client token for authentication.

  ## Examples

      iex> AngelTrading.Client.search_stock("RELIANCE", "valid_token")
      {:ok, %{token_list: [%{exchange: "NSE", symbol_token: "3045", ...}, ...]}}

      iex> AngelTrading.Client.search_stock("INVALID_STOCK", "valid_token")
      {:error, :not_found}

  """
  @spec search_stock(binary, binary) :: {:ok, map} | {:error, atom}
  def search_stock(name, token) do
    case YahooFinance.search(name) do
      {:ok, yahoo_quotes} when yahoo_quotes != [] ->
        token_list =
          yahoo_quotes
          |> Enum.map(
            &(&1.symbol
              |> String.slice(0..(String.length(name) - 1))
              |> String.split(".")
              |> List.first())
          )
          |> MapSet.new()
          |> Enum.map(&API.search_token(token, "NSE", &1))
          |> Enum.flat_map(fn
            {:ok, %{"data" => token_list}} -> token_list
            _ -> []
          end)
          |> Enum.uniq_by(& &1["tradingsymbol"])
          |> Enum.filter(&String.ends_with?(&1["tradingsymbol"], "-EQ"))
          |> Enum.map(
            &(&1
              |> Map.put_new("name", Utils.stock_long_name(&1["tradingsymbol"])))
          )

        {:ok, %{token_list: token_list}}

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Retrieves candle data (RSI) for a given stock over the past week with 1-hour intervals.

  ## Parameters

    - exchange: Stock exchange name.
    - symbol_token: Numeric code for the stock.
    - trading_symbol: Trading symbol for the stock.
    - token: Client token for authentication.

  ## Examples

      iex> AngelTrading.Client.get_candle_data("NSE", "3045", "RELIANCE", "valid_token")
      {:ok, %{candle_data: [%{date: ~U[2023-05-01 10:00:00Z], ...}, ...]}}

      iex> AngelTrading.Client.get_candle_data("INVALID", "123", "INVALID", "valid_token")
      {:error, :invalid_input}

  """
  @spec get_candle_data(binary, binary, binary, binary) :: {:ok, map} | {:error, atom}
  def get_candle_data(exchange, symbol_token, trading_symbol, token) do
    case API.candle_data(
           token,
           exchange,
           symbol_token,
           "ONE_HOUR",
           Timex.now("Asia/Kolkata")
           |> Timex.shift(weeks: -1)
           |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:{0m}"),
           Timex.now("Asia/Kolkata")
           |> Timex.shift(days: 1)
           |> Timex.format!("{YYYY}-{0M}-{0D} {h24}:{0m}")
         ) do
      {:ok, %{"data" => candle_data}} ->
        {:ok, %{candle_data: Utils.formatted_candle_data(candle_data)}}

      _ ->
        {:error, :invalid_input}
    end
  end
end
