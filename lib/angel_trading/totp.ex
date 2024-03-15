defmodule AngelTrading.TOTP do
  @moduledoc """
  This module provides functions for generating and validating Time-based One-Time Passwords (TOTP).
  It uses the Rustler library to leverage the performance of Rust NIFs (Native Implemented Functions).
  """

  use Rustler, otp_app: :angel_trading, crate: "rust_totp"

  @doc """
  Generates the current TOTP value for the given secret.

  This is a NIF (Native Implemented Function) implemented in Rust for better performance.
  If the NIF is not loaded, it will raise an error.

  ## Parameters

    - secret: The secret key used for generating the TOTP.

  ## Examples

      iex> AngelTrading.TOTP.totp_now("ABCDEFGHIJKLMNOP")
      {:ok, "123456"}

  """
  def totp_now(_secret), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Validates the given TOTP value against the secret.

  ## Parameters

    - secret: The secret key used for generating the TOTP.
    - totp: The TOTP value to validate.

  ## Examples

      iex> AngelTrading.TOTP.valid?("ABCDEFGHIJKLMNOP", "123456")
      :ok

      iex> AngelTrading.TOTP.valid?("ABCDEFGHIJKLMNOP", "invalid_totp")
      {:error, :invalid_totp}

  """
  def valid?(secret, totp) do
    case totp_now(secret) do
      {:ok, ^totp} -> :ok
      _ -> {:error, :invalid_totp}
    end
  end
end
