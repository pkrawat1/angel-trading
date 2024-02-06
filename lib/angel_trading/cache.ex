defmodule AngelTrading.Cache do
  @moduledoc """
  Helper for caching data
  """

  require Logger

  @cache_name AngelTrading.Cache

  @doc """
  Fetches the data
  * from cache if exists.
  * from the callback function `fun` returning the data
  """
  def get(cache_key, {fun, args}, expiry \\ :timer.minutes(5)) do
    cache_key = :sha256 |> :crypto.hash(cache_key) |> Base.encode64()

    with {:ok, nil} <- Cachex.get(@cache_name, cache_key),
         {:ok, _} = result <- apply(fun, args) do
      Logger.info("[Cache][MISS][#{cache_key}]")
      Cachex.put(@cache_name, cache_key, result, ttl: expiry)
      result
    else
      {:ok, result} ->
        Logger.info("[Cache][HIT][#{cache_key}]")
        result

      e ->
        Logger.error("[Cache][ERROR][#{cache_key}]")
        IO.inspect(e)
        e
    end
  end
end
