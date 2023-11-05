defmodule AngelTrading.Utils do
  @doc "Encrypt any Erlang term"
  @spec encrypt(atom, any) :: binary
  def encrypt(context, term) do
    Plug.Crypto.encrypt(secret(), to_string(context), term)
  end

  @doc "Decrypt cipher-text into an Erlang term"
  @spec decrypt(atom, binary) :: {:ok, any} | {:error, atom}
  def decrypt(context, ciphertext) when is_binary(ciphertext) do
    Plug.Crypto.decrypt(secret(), to_string(context), ciphertext)
  end

  defp secret(), do: AngelTradingWeb.Endpoint.config(:secret_key_base)
end
