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
  def get(raw_cache_key, {fun, args}, expiry \\ :timer.minutes(15)) do
    cache_key = cache_key(raw_cache_key)

    with {:ok, nil} <- Cachex.get(@cache_name, cache_key),
         {:ok, _} = result <- apply(fun, args) do
      Logger.info("[CACHE][MISS][#{cache_key}]")
      Cachex.put(@cache_name, cache_key, result, ttl: expiry)

      Task.start(fn ->
        Logger.info("[CACHE][RENEW][#{cache_key}] in #{expiry}")
        Process.sleep(expiry)
        get(raw_cache_key, {fun, args}, expiry)
      end)

      result
    else
      {:ok, result} ->
        Logger.info("[CACHE][HIT][#{cache_key}]")
        result

      e ->
        Logger.error("[CACHE][ERROR][#{cache_key}]")
        IO.inspect(e)
        e
    end
  end

  def del(cache_key) do
    cache_key = cache_key(cache_key)
    Cachex.del(@cache_name, cache_key)
  end

  defp cache_key(cache_key), do: :sha256 |> :crypto.hash(cache_key) |> Base.encode64()
end
