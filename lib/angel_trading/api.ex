defmodule AngelTrading.API do
  @moduledoc """
  Interface for the AngelOne API.

  Per-client credentials (api_key, secret_key, proxy_url) are resolved
  automatically from the AngelTrading.ClientConfig ETS store using the
  JWT token — no caller needs to pass credentials explicitly.

  The only exception is `login/2`, which accepts an explicit config map
  because no token exists yet at login time (first-time client registration).
  """

  alias TradeGalleon.Brokers.AngelOne
  alias AngelTrading.{Cache, ClientConfig}

  @doc """
  Start a quote-stream WebSocket for the given client.
  Per-client api_key is resolved automatically from ClientConfig.

  ## Parameters
    - client_code: The client code.
    - token: The access token.
    - feed_token: The feed token.
    - pub_sub_topic: The pub/sub topic to subscribe to.
  """
  def socket(client_code, token, feed_token, pub_sub_topic) do
    with {:ok, config} <- ClientConfig.get_by_token(token) do
      TradeGalleon.call(
        AngelOne.WebSocket,
        :new,
        [api_key: config.api_key],
        params: %{
          client_code: client_code,
          token: token,
          feed_token: feed_token,
          pub_sub_topic: pub_sub_topic
        }
      )
    end
  end

  @doc """
  Start an order-status WebSocket.
  WebSocketOrderStatus does not require a per-client api_key.

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
  Authenticate a client and obtain a JWT token.
  Per-client config is resolved from ClientConfig by client_code.
  This works after the client's encrypted data has been decrypted,
  which populates ClientConfig as a side effect.

  ## Parameters
    - params: Map with client_code, password, totp.
  """
  def login(%{client_code: client_code} = params) do
    with {:ok, config} <- ClientConfig.get_by_client_code(to_string(client_code)) do
      TradeGalleon.call(AngelOne, :login, broker_config(config), params: params)
    end
  end

  @doc """
  Authenticate a client using an explicit config map.
  Used when registering a new client for the first time,
  before any ClientConfig ETS entry exists for them.

  ## Parameters
    - config: Map with api_key, secret_key, proxy_url.
    - params: Map with client_code, password, totp.
  """
  def login(
        %{api_key: _, secret_key: _, proxy_url: _} = config,
        %{client_code: _, password: _, totp: _} = params
      ) do
    TradeGalleon.call(AngelOne, :login, broker_config(config), params: params)
  end

  @doc """
  Log out the client and invalidate the access token.

  ## Parameters
    - token: The access token.
    - client_code: The client code.
  """
  def logout(token, client_code) do
    with {:ok, config} <- ClientConfig.get_by_token(token) do
      TradeGalleon.call(AngelOne, :logout, broker_config(config),
        params: %{client_code: client_code},
        token: token
      )
    end
  end

  @doc """
  Generate a new access token using the refresh token.

  ## Parameters
    - token: The current access token.
    - refresh_token: The refresh token.
  """
  def generate_token(token, refresh_token) do
    with {:ok, config} <- ClientConfig.get_by_token(token) do
      TradeGalleon.call(AngelOne, :generate_token, broker_config(config),
        params: %{refresh_token: refresh_token},
        token: token
      )
    end
  end

  @doc """
  Retrieve the client's profile. Result is cached for 24 hours.

  ## Parameters
    - token: The access token.
  """
  def profile(token) do
    Cache.get(
      "profile_api_" <> token,
      {fn ->
         with {:ok, config} <- ClientConfig.get_by_token(token) do
           TradeGalleon.call(AngelOne, :profile, broker_config(config), token: token)
         end
       end, []},
      :timer.hours(24)
    )
  end

  @doc """
  Retrieve the client's portfolio holdings. Result is cached for 5 minutes.

  ## Parameters
    - token: The access token.
  """
  def portfolio(token) do
    Cache.get(
      "portfolio_api_" <> token,
      {fn ->
         with {:ok, config} <- ClientConfig.get_by_token(token) do
           TradeGalleon.call(AngelOne, :portfolio, broker_config(config), token: token)
         end
       end, []},
      :timer.minutes(5)
    )
  end

  @doc """
  Retrieve full-mode quotes for the given symbol tokens.

  ## Parameters
    - token: The access token.
    - exchange: The exchange code (e.g. "NSE").
    - symbol_tokens: A list of symbol token strings.
  """
  def quote(token, exchange, symbol_tokens) do
    with {:ok, config} <- ClientConfig.get_by_token(token) do
      TradeGalleon.call(AngelOne, :quote, broker_config(config),
        token: token,
        params: %{mode: "FULL", exchange_tokens: %{exchange => symbol_tokens}}
      )
    end
  end

  @doc """
  Retrieve historical candle data for the given symbol and interval.

  ## Parameters
    - token: The access token.
    - exchange: The exchange code.
    - symbol_token: The symbol token.
    - interval: The candle interval (e.g., "ONE_DAY", "ONE_HOUR", "FIFTEEN_MINUTE").
    - from: The start date/time (format: "YYYY-MM-DD HH:MM").
    - to: The end date/time (format: "YYYY-MM-DD HH:MM").
  """
  def candle_data(token, exchange, symbol_token, interval, from, to) do
    with {:ok, config} <- ClientConfig.get_by_token(token) do
      TradeGalleon.call(AngelOne, :candle_data, broker_config(config),
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
  end

  @doc """
  Retrieve the client's available funds.

  ## Parameters
    - token: The access token.
  """
  def funds(token) do
    Cache.get(
      "funds_api_" <> token,
      {fn ->
         with {:ok, config} <- ClientConfig.get_by_token(token) do
           TradeGalleon.call(AngelOne, :funds, broker_config(config), token: token)
         end
       end, []}
    )
  end

  @doc """
  Retrieve the client's open order book.

  ## Parameters
    - token: The access token.
  """
  def order_book(token) do
    with {:ok, config} <- ClientConfig.get_by_token(token) do
      TradeGalleon.call(AngelOne, :order_book, broker_config(config), token: token)
    end
  end

  @doc """
  Retrieve the client's trade history.

  ## Parameters
    - token: The access token.
  """
  def trade_book(token) do
    with {:ok, config} <- ClientConfig.get_by_token(token) do
      TradeGalleon.call(AngelOne, :trade_book, broker_config(config), token: token)
    end
  end

  @doc """
  Search for scrip tokens on the given exchange.

  ## Parameters
    - token: The access token.
    - exchange: The exchange code (e.g. "NSE").
    - query: The search query string.
  """
  def search_token(token, exchange, query) do
    with {:ok, config} <- ClientConfig.get_by_token(token) do
      TradeGalleon.call(AngelOne, :search_token, broker_config(config),
        token: token,
        params: %{exchange: exchange, search_scrip: query}
      )
    end
  end

  @doc """
  Place a new order. Invalidates the funds and portfolio cache.

  ## Parameters
    - token: The access token.
    - order: A map containing the order details:
      - exchange: The exchange code.
      - trading_symbol: The trading symbol.
      - symbol_token: The symbol token.
      - quantity: The quantity.
      - transaction_type: "BUY" or "SELL".
      - order_type: "MARKET" or "LIMIT".
      - variety: "NORMAL", "STOPLOSS", or "AMO".
      - product_type: "DELIVERY" or "INTRADAY".
      - price: The limit price (ignored for MARKET orders).
  """
  def place_order(token, order) do
    reset_cache(token)

    with {:ok, config} <- ClientConfig.get_by_token(token) do
      TradeGalleon.call(AngelOne, :place_order, broker_config(config),
        token: token,
        params: %{
          exchange: order.exchange,
          trading_symbol: order.trading_symbol,
          symbol_token: order.symbol_token,
          quantity: order.quantity,
          transaction_type: order.transaction_type,
          order_type: order.order_type,
          variety: order.variety,
          duration: "DAY",
          product_type: order.product_type,
          price: if(order.order_type == "MARKET", do: 0, else: order.price)
        }
      )
    end
  end

  @doc """
  Modify an existing order. Invalidates the funds and portfolio cache.

  ## Parameters
    - token: The access token.
    - order: A map containing the updated order details:
      - exchange, trading_symbol, symbol_token, quantity, transaction_type,
        order_type, variety, product_type, price: same as place_order.
      - order_id: The ID of the order to modify.
  """
  def modify_order(token, order) do
    reset_cache(token)

    with {:ok, config} <- ClientConfig.get_by_token(token) do
      TradeGalleon.call(AngelOne, :modify_order, broker_config(config),
        token: token,
        params: %{
          exchange: order.exchange,
          trading_symbol: order.trading_symbol,
          symbol_token: order.symbol_token,
          quantity: order.quantity,
          transaction_type: order.transaction_type,
          order_type: order.order_type,
          variety: order.variety,
          duration: "DAY",
          product_type: order.product_type,
          order_id: order.order_id,
          price: if(order.order_type == "MARKET", do: 0, else: order.price)
        }
      )
    end
  end

  @doc """
  Cancel an existing order. Invalidates the funds and portfolio cache.

  ## Parameters
    - token: The access token.
    - order_id: The order ID to cancel.
  """
  def cancel_order(token, order_id) do
    reset_cache(token)

    with {:ok, config} <- ClientConfig.get_by_token(token) do
      TradeGalleon.call(AngelOne, :cancel_order, broker_config(config),
        token: token,
        params: %{variety: "NORMAL", order_id: order_id}
      )
    end
  end

  @doc """
  Retrieve the status of a specific order.

  ## Parameters
    - token: The access token.
    - unique_order_id: The unique order ID.
  """
  def order_status(token, unique_order_id) do
    with {:ok, config} <- ClientConfig.get_by_token(token) do
      TradeGalleon.call(AngelOne, :order_status, broker_config(config),
        token: token,
        params: %{unique_order_id: unique_order_id}
      )
    end
  end

  @doc """
  Verify if the client is eligible to sell a particular stock (DIS check).
  Result is cached for 5 hours.

  ## Parameters
    - token: The access token.
    - isin: The ISIN code of the stock.
  """
  def verify_dis(token, isin) do
    Cache.get(
      "verify_dis_api_" <> token <> "_" <> isin,
      {fn ->
         with {:ok, config} <- ClientConfig.get_by_token(token) do
           case TradeGalleon.call(AngelOne, :verify_dis, broker_config(config),
                  token: token,
                  params: %{isin: isin, quantity: "1"}
                ) do
             {:error, %{"errorcode" => "AG1000"}} -> {:ok, true}
             _ -> {:error, false}
           end
         end
       end, []},
      :timer.hours(5)
    )
  end

  @doc """
  Estimate brokerage charges for a list of orders before placing them.

  ## Parameters
    - token: The access token.
    - orders: A list of order detail maps, each containing:
      - product_type: "DELIVERY" or "INTRADAY".
      - transaction_type: "BUY" or "SELL".
      - quantity: The quantity.
      - price: The order price.
      - exchange: The exchange code.
      - trading_symbol: The trading symbol.
      - symbol_token: The symbol token.
  """
  def estimate_charges(token, orders) do
    with {:ok, config} <- ClientConfig.get_by_token(token) do
      TradeGalleon.call(AngelOne, :estimate_charges, broker_config(config),
        token: token,
        params: %{
          orders:
            Enum.map(orders, fn order ->
              %{
                product_type: order.product_type,
                transaction_type: order.transaction_type,
                quantity: order.quantity,
                price: order.price,
                exchange: order.exchange,
                symbol_name: order.trading_symbol,
                token: order.symbol_token
              }
            end)
        }
      )
    end
  end

  @doc """
  Invalidate the funds and portfolio cache entries for the given token.
  Called automatically by place_order, modify_order, and cancel_order.

  ## Parameters
    - token: The access token.
  """
  def reset_cache(token) do
    Cache.del("funds_api_" <> token)
    Cache.del("portfolio_api_" <> token)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Converts a ClientConfig entry into the keyword list TradeGalleon.call/4 expects.
  # proxy_url is optional; when nil Hackney uses no proxy (direct connection).
  defp broker_config(%{api_key: api_key, secret_key: secret_key, proxy_url: proxy_url}) do
    [api_key: api_key, secret_key: secret_key, proxy_url: proxy_url]
  end
end
