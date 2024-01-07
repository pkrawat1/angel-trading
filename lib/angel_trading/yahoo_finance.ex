defmodule AngelTrading.YahooFinance do
  use Rustler, otp_app: :angel_trading, crate: "yahoo_finance"

  # When your NIF is loaded, it will override this function.
  def search(_company_name), do: :erlang.nif_error(:nif_not_loaded)
end
