defmodule AngelTrading.API do
  alias TradeGalleon.Brokers.AngelOne
  alias AngelTrading.Cache

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

  def login(params) do
    TradeGalleon.call(AngelOne, :login, params: params)
  end

  def logout(token, client_code) do
    TradeGalleon.call(AngelOne, :logout, params: %{"clientcode" => client_code}, token: token)
  end

  def generate_token(token, refresh_token) do
    TradeGalleon.call(AngelOne, :generate_token,
      params: %{"refreshToken" => refresh_token},
      token: token
    )
  end

  def profile(token) do
    Cache.get(
      "profile_api_" <> token,
      {fn ->
         TradeGalleon.call(AngelOne, :profile, token: token)
       end, []},
      :timer.hours(24)
    )
  end

  def portfolio(token) do
    Cache.get(
      "portfolio_api_" <> token,
      {fn ->
         TradeGalleon.call(AngelOne, :portfolio, token: token)
       end, []},
      :timer.minutes(5)
    )
  end

  def quote(token, exchange, symbol_tokens) do
    TradeGalleon.call(AngelOne, :quote,
      token: token,
      params: %{
        mode: "FULL",
        exchangeTokens: %{
          exchange => symbol_tokens
        }
      }
    )
  end

  def candle_data(token, exchange, symbol_token, interval, from, to) do
    TradeGalleon.call(AngelOne, :candle_data,
      token: token,
      params: %{
        "exchange" => exchange,
        "symboltoken" => symbol_token,
        "interval" => interval,
        "fromdate" => from,
        "todate" => to
      }
    )
  end

  def funds(token) do
    Cache.get(
      "funds_api_" <> token,
      {fn ->
         TradeGalleon.call(AngelOne, :funds, token: token)
       end, []}
    )
  end

  def order_book(token) do
    TradeGalleon.call(AngelOne, :order_book, token: token)
  end

  def trade_book(token) do
    TradeGalleon.call(AngelOne, :trade_book, token: token)
  end

  def search_token(token, exchange, query) do
    TradeGalleon.call(AngelOne, :search_token,
      token: token,
      params: %{
        "exchange" => exchange,
        "searchscrip" => query
      }
    )
  end

  def place_order(
        token,
        %{
          exchange: exchange,
          trading_symbol: trading_symbol,
          symbol_token: symbol_token,
          quantity: quantity,
          transaction_type: transaction_type,
          order_type: order_type,
          variety: variety,
          product_type: product_type,
          price: price
        }
      ) do
    reset_cache(token)

    TradeGalleon.call(AngelOne, :place_order,
      token: token,
      params: %{
        "exchange" => exchange,
        "tradingsymbol" => trading_symbol,
        "symboltoken" => symbol_token,
        "quantity" => quantity,
        "transactiontype" => transaction_type,
        "ordertype" => order_type,
        "variety" => variety,
        "duration" => "DAY",
        "producttype" => product_type,
        "price" => if(order_type == "MARKET", do: 0, else: price)
      }
    )
  end

  def modify_order(
        token,
        %{
          exchange: exchange,
          trading_symbol: trading_symbol,
          symbol_token: symbol_token,
          quantity: quantity,
          transaction_type: transaction_type,
          order_type: order_type,
          variety: variety,
          product_type: product_type,
          order_id: order_id,
          price: price
        }
      ) do
    reset_cache(token)

    TradeGalleon.call(AngelOne, :modify_order,
      token: token,
      params: %{
        "exchange" => exchange,
        "tradingsymbol" => trading_symbol,
        "symboltoken" => symbol_token,
        "quantity" => quantity,
        "transactiontype" => transaction_type,
        "ordertype" => order_type,
        "variety" => variety,
        "duration" => "DAY",
        "producttype" => product_type,
        "orderid" => order_id,
        "price" => if(order_type == "MARKET", do: 0, else: price)
      }
    )
  end

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

  def order_status(token, unique_order_id) do
    TradeGalleon.call(AngelOne, :order_status,
      token: token,
      params: %{
        "unique_order_id" => unique_order_id
      }
    )
  end

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

  def reset_cache(token) do
    Cache.del("funds_api_" <> token)
    Cache.del("portfolio_api_" <> token)
  end
end
