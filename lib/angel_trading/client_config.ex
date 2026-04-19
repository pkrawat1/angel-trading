defmodule AngelTrading.ClientConfig do
  @moduledoc """
  In-memory per-client credential store backed by ETS.

  Entries are keyed by both JWT token and client_code so that:
    - Post-login API calls look up config by token (fast).
    - The login call itself can look up config by client_code (populated
      as a side effect of Utils.decrypt/2 for :client_tokens).

  When a client's token is refreshed the old token entry is cleaned up
  automatically to avoid memory leaks.
  """

  use GenServer

  @table :angel_client_config

  # ---------------------------------------------------------------------------
  # Public API (called from any process — ETS is :public)
  # ---------------------------------------------------------------------------

  @doc "Store per-client config indexed by both token and client_code."
  @spec put(binary, binary, map) :: :ok
  def put(client_code, token, %{api_key: _, secret_key: _, proxy_url: _} = config) do
    # Remove the stale token entry if the client already has one.
    case :ets.lookup(@table, {:client_code, client_code}) do
      [{{:client_code, ^client_code}, {old_token, _}}] when old_token != token ->
        :ets.delete(@table, {:token, old_token})

      _ ->
        :ok
    end

    :ets.insert(@table, {{:token, token}, {client_code, config}})
    :ets.insert(@table, {{:client_code, client_code}, {token, config}})
    :ok
  end

  @doc "Retrieve config for a JWT token. Returns {:ok, config} | {:error, :not_found}."
  @spec get_by_token(binary) :: {:ok, map} | {:error, :not_found}
  def get_by_token(token) do
    case :ets.lookup(@table, {:token, token}) do
      [{{:token, ^token}, {_client_code, config}}] -> {:ok, config}
      [] -> {:error, :not_found}
    end
  end

  @doc "Retrieve config for a client code. Returns {:ok, config} | {:error, :not_found}."
  @spec get_by_client_code(binary) :: {:ok, map} | {:error, :not_found}
  def get_by_client_code(client_code) do
    case :ets.lookup(@table, {:client_code, client_code}) do
      [{{:client_code, ^client_code}, {_token, config}}] -> {:ok, config}
      [] -> {:error, :not_found}
    end
  end

  @doc "Remove ETS entries for a token and its associated client_code."
  @spec delete_by_token(binary) :: :ok
  def delete_by_token(token) do
    case :ets.lookup(@table, {:token, token}) do
      [{{:token, ^token}, {client_code, _}}] ->
        :ets.delete(@table, {:token, token})
        :ets.delete(@table, {:client_code, client_code})

      [] ->
        :ok
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # GenServer (only needed to own and initialise the ETS table)
  # ---------------------------------------------------------------------------

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl GenServer
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, %{}}
  end
end
