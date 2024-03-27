defmodule AngelTrading.API do
  @moduledoc """
  This module provides an interface for interacting with the AngelOne API.
  """

  alias TradeGalleon.Brokers.AngelOne
  alias AngelTrading.Cache

  @doc """
  Create a new WebSocket connection for streaming market data.

  ## Parameters
    - client_code: The client code.
    - token: The access token.
    - feed_token: The feed token.
    - pub_sub_topic: The pub/sub topic to subscribe to.
  """
  def socket(client_code, token, feed_token, pub_sub_topic) do
    TradeGalleon.call(AngelOne.WebSocket, :new,
      params: %{
        client_code: client_code,
        token: token,
        feed_token: feed_token,
        pub_sub_topic: pub_sub_topic
      }
    )
  end

  @doc """
  Create a new WebSocket connection for streaming order status updates.

  ## Parameters
    - client_code: The client code.
    - token: The access token.
    - feed_token: The feed token.
    - pub_sub_topic: The pub/sub topic to subscribe to.
  """
  def order_socket(client_code, token, feed_token, pub_sub_topic) do
    TradeGalleon.call(AngelOne.WebSocketOrderStatus, :new,
      params: %{
        client_code: client_code,
        token: token,
        feed_token: feed_token,
        pub_sub_topic: pub_sub_topic
      }
    )
  end

  @doc """
  Authenticate the user and obtain an access token.

  ## Map containing the login parameters:
    - client_code: The client code.
    - password: The password.
    - totp: The TOTP
  """
  def login(%{client_code: _, password: _, totp: _} = params),
    do: TradeGalleon.call(AngelOne, :login, params: params)

  @doc """
  Log out the user and invalidate the access token.

  ## Parameters
    - token: The access token.
    - client_code: The client code.
  """
  def logout(token, client_code),
    do:
      TradeGalleon.call(AngelOne, :logout, params: %{"client_code" => client_code}, token: token)

  @doc """
  Generate a new access token using the refresh token.

  ## Parameters
    - token: The current access token.
    - refresh_token: The refresh token.
  """
  def generate_token(token, refresh_token),
    do:
      TradeGalleon.call(AngelOne, :generate_token,
        params: %{"refresh_token" => refresh_token},
        token: token
      )

  @doc """
  Retrieve the user's profile.

  ## Parameters
    - token: The access token.
  """
  def profile(token) do
    Cache.get(
      "profile_api_" <> token,
      {fn ->
         TradeGalleon.call(AngelOne, :profile, token: token)
       end, []},
      :timer.hours(24)
    )
  end

  @doc """
  Retrieve the user's portfolio.

  ## Parameters
    - token: The access token.
  """
  def portfolio(token) do
    Cache.get(
      "portfolio_api_" <> token,
      {fn ->
         TradeGalleon.call(AngelOne, :portfolio, token: token)
       end, []},
      :timer.minutes(5)
    )
  end

  @doc """
  Retrieve quotes for the given symbols.

  ## Parameters
    - token: The access token.
    - exchange: The exchange code.
    - symbol_tokens: A list of symbol tokens.
  """
  def quote(token, exchange, symbol_tokens) do
    TradeGalleon.call(AngelOne, :quote,
      token: token,
      params: %{
        mode: "FULL",
        exchange_tokens: %{
          exchange => symbol_tokens
        }
      }
    )
  end

  @doc """
  Retrieve historical candle data for the given symbol and interval.

  ## Parameters
    - token: The access token.
    - exchange: The exchange code.
    - symbol_token: The symbol token.
    - interval: The candle interval (e.g., "ONE_DAY", "ONE_HOUR", "FIFTEEN_MINUTES").
    - from: The start date (format: "{YYYY}-{0M}-{0D} {h24}:{0m}").
    - to: The end date (format: "{YYYY}-{0M}-{0D} {h24}:{0m}").
  """
  def candle_data(token, exchange, symbol_token, interval, from, to) do
    TradeGalleon.call(AngelOne, :candle_data,
      token: token,
      params: %{
        exchange: exchange,
        symbol_token: symbol_token,
        interval: interval,
        from_date: from,
        to_date: to
      }
    )
  end

  @doc """
  Retrieve the user's funds.

  ## Parameters
    - token: The access token.
  """
  def funds(token) do
    Cache.get(
      "funds_api_" <> token,
      {fn ->
         TradeGalleon.call(AngelOne, :funds, token: token)
       end, []}
    )
  end

  @doc """
  Retrieve the user's open orders.

  ## Parameters
    - token: The access token.
  """
  def order_book(token), do: TradeGalleon.call(AngelOne, :order_book, token: token)

  @doc """
  Retrieve the user's trade history.

  ## Parameters
    - token: The access token.
  """
  def trade_book(token), do: TradeGalleon.call(AngelOne, :trade_book, token: token)

  @doc """
  Search for symbols on the given exchange.

  ## Parameters
    - token: The access token.
    - exchange: The exchange code.
    - query: The search query.
  """
  def search_token(token, exchange, query) do
    TradeGalleon.call(AngelOne, :search_token,
      token: token,
      params: %{
        "exchange" => exchange,
        "searchscrip" => query
      }
    )
  end

  @doc """
  Place a new order.

  ## Parameters
    - token: The access token.
    - order: A map containing the order details:
      - exchange: The exchange code.
      - trading_symbol: The trading symbol.
      - symbol_token: The symbol token.
      - quantity: The quantity.
      - transaction_type: The transaction type (e.g., "BUY", "SELL").
      - order_type: The order type (e.g., "MARKET", "LIMIT").
      - variety: The order variety (e.g., "NORMAL", "STOPLOSS", "AMO").
      - product_type: The product type (e.g., "DELIVERY", "INTRADAY").
      - price: The order price (for limit orders).
  """
  def place_order(token, order) do
    reset_cache(token)

    TradeGalleon.call(AngelOne, :place_order,
      token: token,
      params: %{
        "exchange" => order.exchange,
        "tradingsymbol" => order.trading_symbol,
        "symboltoken" => order.symbol_token,
        "quantity" => order.quantity,
        "transactiontype" => order.transaction_type,
        "ordertype" => order.order_type,
        "variety" => order.variety,
        "duration" => "DAY",
        "producttype" => order.product_type,
        "price" => if(order.order_type == "MARKET", do: 0, else: order.price)
      }
    )
  end

  @doc """
  Modify an existing order.

  ## Parameters
    - token: The access token.
    - order: A map containing the order details:
      - exchange: The exchange code.
      - trading_symbol: The trading symbol.
      - symbol_token: The symbol token.
      - quantity: The new quantity.
      - transaction_type: The transaction type (e.g., "BUY", "SELL").
      - order_type: The new order type (e.g., "MARKET", "LIMIT").
      - variety: The order variety (e.g., "NORMAL", "STOPLOSS", "AMO").
      - product_type: The product type (e.g., "DELIVERY", "INTRADAY").
      - order_id: The order ID to modify.
      - price: The new order price (for limit orders).
  """
  def modify_order(token, order) do
    reset_cache(token)

    TradeGalleon.call(AngelOne, :modify_order,
      token: token,
      params: %{
        "exchange" => order.exchange,
        "tradingsymbol" => order.trading_symbol,
        "symboltoken" => order.symbol_token,
        "quantity" => order.quantity,
        "transactiontype" => order.transaction_type,
        "ordertype" => order.order_type,
        "variety" => order.variety,
        "duration" => "DAY",
        "producttype" => order.product_type,
        "orderid" => order.order_id,
        "price" => if(order.order_type == "MARKET", do: 0, else: order.price)
      }
    )
  end

  @doc """
  Cancel an existing order.

  ## Parameters
    - token: The access token.
    - order_id: The order ID to cancel.
  """
  def cancel_order(token, order_id) do
    reset_cache(token)

    TradeGalleon.call(AngelOne, :cancel_order,
      token: token,
      params: %{
        "variety" => "NORMAL",
        "orderid" => order_id
      }
    )
  end

  @doc """
  Retrieve the status of an order.

  ## Parameters
    - token: The access token.
    - unique_order_id: The unique order ID.
  """
  def order_status(token, unique_order_id) do
    TradeGalleon.call(AngelOne, :order_status,
      token: token,
      params: %{
        "unique_order_id" => unique_order_id
      }
    )
  end

  @doc """
  Verify if the user is eligible to trade a particular stock.

  ## Parameters
    - token: The access token.
    - isin: The ISIN code of the stock.
  """
  def verify_dis(token, isin) do
    Cache.get(
      "verify_dis_api_" <> token <> "_" <> isin,
      {fn ->
         case TradeGalleon.call(AngelOne, :verify_dis,
                token: token,
                params: %{
                  "isin" => isin,
                  "quantity" => "1"
                }
              ) do
           {:error, %{"errorcode" => errorcode}} when errorcode == "AG1000" -> {:ok, true}
           _ -> {:error, false}
         end
       end, []},
      :timer.hours(5)
    )
  end

  @doc """
  Estimate the charges for a list of orders.

  ## Parameters
    - token: The access token.
    - orders: A list of maps containing the order details:
      - product_type: The product type (e.g., "DELIVERY", "INTRADAY").
      - transaction_type: The transaction type (e.g., "BUY", "SELL").
      - quantity: The quantity.
      - price: The order price.
      - exchange: The exchange code.
      - trading_symbol: The trading symbol.
      - symbol_token: The symbol token.
  """
  def estimate_charges(token, orders) do
    TradeGalleon.call(AngelOne, :estimate_charges,
      token: token,
      params: %{
        "orders" =>
          Enum.map(orders, fn order ->
            %{
              "product_type" => order.product_type,
              "transaction_type" => order.transaction_type,
              "quantity" => order.quantity,
              "price" => order.price,
              "exchange" => order.exchange,
              "symbol_name" => order.trading_symbol,
              "token" => order.symbol_token
            }
          end)
      }
    )
  end

  @doc """
  Reset the cache for the user's funds and portfolio.

  ## Parameters
    - token: The access token.
  """
  def reset_cache(token) do
    Cache.del("funds_api_" <> token)
    Cache.del("portfolio_api_" <> token)
  end
end
