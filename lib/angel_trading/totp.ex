defmodule AngelTrading.TOTP do
  use Rustler, otp_app: :angel_trading, crate: "rust_totp"

  # When your NIF is loaded, it will override this function.
  def totp_now(_secret), do: :erlang.nif_error(:nif_not_loaded)
end

