defmodule AngelTrading.UserMail do
  import Swoosh.Email
  alias AngelTrading.{TOTP, Utils}

  def totp_now(email) do
    {:ok, totp} =
      :email_totp
      |> Utils.encrypt(email)
      |> Base.encode32()
      |> TOTP.totp_now()

    new()
    |> from({"Smartrade", "no-reply@smartrade.com"})
    |> to(email)
    |> subject("Subject: TOTP for Smartrade")
    |> text_body("TOTP for login: #{totp}")
  end
end
