defmodule AngelTrading.Cache do
  @moduledoc """
  Helper module for caching data.
  """

  require Logger
  require Timex

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

    # Adjust expiry based on current time in IST
    expiry = adjust_expiry_based_on_time(expiry)

    case Cachex.get(@cache_name, cache_key) do
      {:ok, nil} ->
        # Cache miss
        Logger.info("[CACHE][MISS][#{cache_key}]")
        handle_cache_miss_or_error(raw_cache_key, fun, args, expiry)

      {:ok, {:error, _}} ->
        # Cache error
        Logger.error("[CACHE][ERROR][#{cache_key}]")
        handle_cache_miss_or_error(raw_cache_key, fun, args, expiry)

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

  defp cache_key(raw_cache_key) do
    case String.split(raw_cache_key, "_api_") do
      [fn_name, token] ->
        hashed_token = :crypto.hash(:sha256, token) |> Base.encode64()
        "#{fn_name}_api_#{hashed_token}"

      _ ->
        raise "Invalid cache key format"
    end
  end

  defp start_renewal_task(raw_cache_key, {fun, args}, expiry) do
    Task.start(fn ->
      # Skip renewal if expiry is :infinity
      if expiry != :infinity do
        Logger.info(
          "[CACHE][TRIGGER-RENEW][#{cache_key(raw_cache_key)}] in #{expiry / (1000 * 60)} minutes"
        )

        Process.sleep(expiry)
        get(raw_cache_key, {fun, args}, expiry)
      else
        Logger.info("[CACHE][NO-RENEWAL][#{cache_key(raw_cache_key)}] due to infinite expiry")
      end
    end)
  end

  def handle_cache_miss_or_error(raw_cache_key, fun, args, expiry) do
    cache_key = cache_key(raw_cache_key)
    result = apply(fun, args)
    Logger.info("[CACHE][RENEWED][#{cache_key}]")
    Cachex.put(@cache_name, cache_key, result, ttl: expiry)
    start_renewal_task(raw_cache_key, {fun, args}, expiry)
    result
  end

  # Helper function to adjust expiry based on the current time in IST
  defp adjust_expiry_based_on_time(expiry) do
    # Get the current time in IST
    current_time = Timex.now("Asia/Kolkata")

    start_time = Timex.set(current_time, hour: 9, minute: 0, second: 0)
    end_time = Timex.set(current_time, hour: 15, minute: 45, second: 0)

    if Timex.after?(current_time, start_time) and Timex.before?(current_time, end_time) do
      expiry
    else
      :infinity
    end
  end
end
