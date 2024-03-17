defmodule TOTPTest do
  use ExUnit.Case

  import Mock

  test "generates the current TOTP value for the given secret" do
    with_mock AngelTrading.TOTP, totp_now: fn _secret -> {:ok, "123456"} end do
      assert {:ok, "123456"} == AngelTrading.TOTP.totp_now("JBSWY3DPEHPK3PXP")
    end
  end

  test "validates the given TOTP value against the secret" do
    with_mock AngelTrading.TOTP, valid?: fn _secret, _totp -> :ok end do
      assert :ok == AngelTrading.TOTP.valid?("JBSWY3DPEHPK3PXP", "123456")
    end

    with_mock AngelTrading.TOTP, valid?: fn _secret, _totp -> {:error, :invalid_totp} end do
      assert {:error, :invalid_totp} ==
               AngelTrading.TOTP.valid?("JBSWY3DPEHPK3PXP", "invalid_totp")
    end
  end
end
