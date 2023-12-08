defmodule AngelTrading.API do
  use Tesla
  alias TradeGalleon.Brokers.AngelOne

  def socket(client_code, token, feed_token) do
    AngelTrading.WebSocket.start_link(%{
      client_code: client_code,
      token: token,
      feed_token: feed_token
    })
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
    TradeGalleon.call(AngelOne, :profile, token: token)
  end

  def portfolio(token) do
    TradeGalleon.call(AngelOne, :portfolio, token: token)
  end

  def quote(token, exchange, symbol_token) do
    TradeGalleon.call(AngelOne, :quote,
      token: token,
      params: %{
        mode: "FULL",
        exchangeTokens: %{
          exchange => [symbol_token]
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
    TradeGalleon.call(AngelOne, :funds, token: token)
  end

  def order_book(token) do
    TradeGalleon.call(AngelOne, :order_book, token: token)
  end

  def trade_book(token) do
    TradeGalleon.call(AngelOne, :trade_book, token: token)
  end
end
