defmodule AngelTrading.Cache do
  @moduledoc """
  Helper module for caching data.
  """

  require Logger

  @cache_name AngelTrading.Cache

  @doc """
  Fetches data from the cache or calls a function to retrieve the data if it's not in the cache.

  ## Parameters

    - raw_cache_key: The raw cache key to use for caching.
    - fun: A tuple containing the function to call if the data is not in the cache, and its arguments.
    - expiry: The time-to-live (TTL) for the cached data (defaults to 15 minutes).

  ## Examples

      iex> AngelTrading.Cache.get("my_key", {fn -> expensive_operation() end, []})
      {:ok, result}

  """
  def get(raw_cache_key, {fun, args}, expiry \\ :timer.minutes(15)) do
    cache_key = cache_key(raw_cache_key)

    case Cachex.get(@cache_name, cache_key) do
      {:ok, nil} ->
        # Cache miss, fetch data and cache it
        result = apply(fun, args)
        Logger.info("[CACHE][RENEWED][#{cache_key}]")
        Cachex.put(@cache_name, cache_key, result, ttl: expiry)
        start_renewal_task(raw_cache_key, {fun, args}, expiry)
        result

      {:ok, cached_data} ->
        # Cache hit
        Logger.info("[CACHE][HIT][#{cache_key}]")
        cached_data

      error ->
        # Error occurred
        Logger.error("[CACHE][ERROR][#{cache_key}]")
        IO.inspect(error)
        error
    end
  end

  @doc """
  Deletes an entry from the cache.

  ## Parameters

    - cache_key: The cache key to delete.

  """
  def del(cache_key) do
    cache_key = cache_key(cache_key)
    Cachex.del(@cache_name, cache_key)
  end

  # Private functions

  defp cache_key(raw_cache_key), do: :sha256 |> :crypto.hash(raw_cache_key) |> Base.encode64()

  defp start_renewal_task(raw_cache_key, {fun, args}, expiry) do
    Task.start(fn ->
      Logger.info(
        "[CACHE][TRIGGER-RENEW][#{cache_key(raw_cache_key)}] in #{expiry / (1000 * 60)} minutes"
      )

      Process.sleep(expiry)
      get(raw_cache_key, {fun, args}, expiry)
    end)
  end
end
