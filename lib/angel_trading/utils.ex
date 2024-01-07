defmodule AngelTrading.Utils do
  @max_age :infinity

  @doc "Encrypt any Erlang term"
  @spec encrypt(atom, any, integer) :: binary
  def encrypt(context, term, max_age \\ @max_age) do
    Plug.Crypto.encrypt(secret(), to_string(context), term, max_age: max_age)
  end

  @doc "Decrypt cipher-text into an Erlang term"
  @spec decrypt(atom, binary, integer) :: {:ok, any} | {:error, atom}
  def decrypt(context, ciphertext, max_age \\ @max_age) when is_binary(ciphertext) do
    Plug.Crypto.decrypt(secret(), to_string(context), ciphertext, max_age: max_age)
  end

  # Using float calculation as of now. Since most of the data is coming from angel api.
  # I could add ex_money to manage calculations in decimal money format.
  def formatted_holdings(holdings) do
    holdings
    # Filter cases where stock is in split state
    |> Enum.filter(&(&1["symboltoken"] != ""))
    |> Enum.filter(&(&1["quantity"] != 0))
    |> Enum.filter(&(&1 != nil))
    |> Enum.map(fn %{
                     "authorisedquantity" => _,
                     "averageprice" => averageprice,
                     "close" => close,
                     "collateralquantity" => _,
                     "collateraltype" => _,
                     "exchange" => _,
                     "haircut" => _,
                     "isin" => _,
                     "ltp" => ltp,
                     "product" => _,
                     "profitandloss" => _,
                     "quantity" => quantity,
                     "realisedquantity" => realisedquantity,
                     "symboltoken" => symboltoken,
                     "t1quantity" => _,
                     "tradingsymbol" => _
                   } = holding ->
      averageprice = if averageprice > 0, do: averageprice, else: close
      close = if realisedquantity > 0, do: close, else: averageprice
      invested = quantity * averageprice
      current = quantity * ltp
      overall_gain_or_loss = quantity * (ltp - averageprice)
      overall_gain_or_loss_percent = overall_gain_or_loss / invested * 100
      todays_profit_or_loss = quantity * (ltp - close)
      todays_profit_or_loss_percent = todays_profit_or_loss / invested * 100
      ltp_percent = (ltp - close) / close * 100

      Map.merge(holding, %{
        "invested" => invested,
        "current" => current,
        "in_overall_profit?" => current > invested,
        "is_gain_today?" => ltp > close,
        "overall_gain_or_loss" => overall_gain_or_loss,
        "overall_gain_or_loss_percent" => overall_gain_or_loss_percent,
        "todays_profit_or_loss" => todays_profit_or_loss,
        "todays_profit_or_loss_percent" => todays_profit_or_loss_percent,
        "ltp_percent" => ltp_percent,
        id: symboltoken
      })
    end)
  end

  def calculated_overview(socket, holdings) do
    total_invested = holdings |> Enum.map(& &1["invested"]) |> Enum.sum()
    total_overall_gain_or_loss = holdings |> Enum.map(& &1["overall_gain_or_loss"]) |> Enum.sum()
    total_todays_gain_or_loss = holdings |> Enum.map(& &1["todays_profit_or_loss"]) |> Enum.sum()

    Phoenix.Component.assign(socket,
      holdings: holdings |> Enum.sort(&(&2["tradingsymbol"] >= &1["tradingsymbol"])),
      total_invested: total_invested,
      total_current: holdings |> Enum.map(& &1["current"]) |> Enum.sum(),
      total_overall_gain_or_loss: total_overall_gain_or_loss,
      total_todays_gain_or_loss: total_todays_gain_or_loss,
      in_overall_profit_today?: total_todays_gain_or_loss > 0,
      in_overall_profit?: total_overall_gain_or_loss > 0,
      total_overall_gain_or_loss_percent: total_overall_gain_or_loss / total_invested * 100,
      total_todays_gain_or_loss_percent: total_todays_gain_or_loss / total_invested * 100
    )
  end

  def formatted_candle_data(candle_data) do
    # temp = List.last(candle_data)

    Enum.map(
      candle_data,
      fn [timestamp, open, high, low, close, volume] ->
        %{
          # read timestamp as UTC
          time:
            timestamp
            |> String.split("+")
            |> List.first()
            |> Timex.parse!("{ISO:Extended:Z}")
            |> Timex.to_unix(),
          open: open,
          high: high,
          low: low,
          close: close,
          volume: volume
        }
      end
    )

    # ++
    # [
    # %{
    # time: Timex.now() |> Timex.shift(hours: Enum.random(1..100)) |> Timex.to_unix(),
    # timestamp:
    # Timex.now("Asia/Kolkata")
    # |> Timex.shift(hours: Enum.random(1..100))
    # |> Timex.format!("%FT%T%:z", :strftime),
    # open: Enum.at(temp, 1) + Enum.random(-2..5),
    # high: Enum.at(temp, 2),
    # low: Enum.at(temp, 3),
    # close: Enum.at(temp, 4),
    # volume: Enum.at(temp, 5)
    # }
    # ]
  end

  def stock_long_name(trading_symbol) do
    symbol = trading_symbol |> String.split("-") |> List.first()

    case AngelTrading.YahooFinance.search(symbol) do
      {:ok, [%{long_name: long_name}]} -> long_name
      _ -> trading_symbol
    end
  end

  defp secret(), do: Application.get_env(:angel_trading, :encryption_key)
end
