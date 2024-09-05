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
         {:portfolio, {:ok, %{"data" => %{holdings: holdings}}}} <-
           {:portfolio, API.portfolio(token)},
         {:funds, {:ok, %{"data" => funds}}} <- {:funds, API.funds(token)} do
      {:ok,
       Map.merge(
         %{
           profile: profile,
           funds: funds
         },
         holdings
         |> Utils.formatted_holdings()
         |> Utils.calculated_overview()
       )}
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
            {:ok, %{"data" => %{scrips: token_list}}} -> token_list
            _ -> []
          end)
          |> Enum.uniq_by(& &1.trading_symbol)
          |> Enum.filter(&String.ends_with?(&1.trading_symbol, "-EQ"))
          |> Enum.map(
            &(&1
              |> Map.put_new(:name, Utils.stock_long_name(&1.trading_symbol)))
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
    - token: Client token for authentication.

  ## Examples

      iex> AngelTrading.Client.get_candle_data("NSE", "3045", "valid_token")
      {:ok, %{candle_data: [%{date: ~U[2023-05-01 10:00:00Z], ...}, ...]}}

      iex> AngelTrading.Client.get_candle_data("INVALID", "123", "valid_token")
      {:error, :invalid_input}

  """
  @spec get_candle_data(binary, binary, binary) :: {:ok, map} | {:error, atom}
  def get_candle_data(exchange, symbol_token, token) do
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
      {:ok, %{"data" => %{data: candle_data}}} ->
        {:ok, %{candle_data: Utils.formatted_candle_data(candle_data)}}

      _ ->
        {:error, :invalid_input}
    end
  end

  @doc """
  Returns a function that fetches the client's portfolio information.

  ## Examples

      iex> AngelTrading.Client.client_portfolio_info_function()
      %LangChain.Function{...}

  """
  @spec client_portfolio_info_function :: LangChain.Function.t()
  def client_portfolio_info_function do
    LangChain.Function.new!(%{
      name: "get_client_portfolio_info",
      description: "Return JSON object of the client's information.",
      function: &client_portfolio_info_fn/2,
      parameter_schema: %{
        type: "object",
        properties: %{},
        required: []
      }
    })
  end

  defp client_portfolio_info_fn(_args, %{client_token: token, live_view_pid: pid} = _context) do
    send(pid, {:function_run, "Retrieving client portfolio information."})

    case get_client_portfolio_info(token) do
      {:ok, result} ->
        Jason.encode!(result)

      _ ->
        Jason.encode!(%{error: "Unable to fetch the client portfolio."})
    end
  end

  @doc """
  Returns a function that searches for stock details based on the provided name.

  ## Examples

      iex> AngelTrading.Client.search_stock_function()
      %LangChain.Function{...}

  """
  @spec search_stock_function :: LangChain.Function.t()
  def search_stock_function do
    LangChain.Function.new!(%{
      name: "search_stock_details",
      description: "Return JSON object of the stock details like symbol, token, exchange etc.",
      parameters: [
        LangChain.FunctionParam.new!(%{
          name: "name",
          type: "string",
          description: "Stock name to search for."
        })
      ],
      function: &search_stock_fn/2
    })
  end

  defp search_stock_fn(%{"name" => name}, %{client_token: token, live_view_pid: pid} = _context) do
    send(pid, {:function_run, "Retrieving stock information for #{name}"})

    with {:ok, result} <- search_stock(name, token) do
      Jason.encode!(result)
    else
      _ -> Jason.encode!(%{error: "No match found for the name."})
    end
  end

  @doc """
  Returns a function that retrieves candle data (RSI) for a given stock.

  ## Examples

      iex> AngelTrading.Client.candle_data_function()
      %LangChain.Function{...}

  """
  @spec candle_data_function :: LangChain.Function.t()
  def candle_data_function do
    LangChain.Function.new!(%{
      name: "get_candle_data",
      description:
        "Return JSON object of the candle data (RSI) for a stock recorded in 1 week time with 1 hour gap.",
      parameters: [
        LangChain.FunctionParam.new!(%{
          name: "exchange",
          type: "string",
          description: "Exchange name"
        }),
        LangChain.FunctionParam.new!(%{
          name: "symbol_token",
          type: "string",
          description: "Symbol token is numeric code for the stock found in stock detail"
        }),
        LangChain.FunctionParam.new!(%{
          name: "trading_symbol",
          type: "string",
          description: "Trading symbol for the stock found in the stock details details"
        })
      ],
      function: &candle_data_fn/2
    })
  end

  defp candle_data_fn(
         %{
           "exchange" => exchange,
           "symbol_token" => symbol_token,
           "trading_symbol" => trading_symbol
         },
         %{client_token: token, live_view_pid: pid} = _context
       ) do
    send(pid, {:function_run, "Retrieving candle data information for #{trading_symbol}"})

    with {:ok, result} <- get_candle_data(exchange, symbol_token, token) do
      Jason.encode!(result)
    else
      _ -> Jason.encode!(%{error: "Unable to fetch the candle data."})
    end
  end
end
