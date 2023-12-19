defmodule AngelTradingWeb.WatchlistLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.{Account, API, Utils}
  require Logger

  def mount(_params, %{"user_hash" => user_hash}, socket) do
    # :timer.send_interval(2000, self(), :subscribe_to_feed)
    socket =
      with {:ok, %{body: %{"client_code" => client_code}}} <- Account.get_user(user_hash),
           {:ok, %{body: data}} when is_binary(data) <- Account.get_client(client_code),
           {:ok, %{token: token}} <- Utils.decrypt(:client_tokens, data) do
        assign(socket, token: token)
      else
        _ -> socket
      end

    {:ok,
     socket
     |> assign(:page_title, "Watchlist")
     |> assign(:user_hash, user_hash)
     |> assign(:token_list, [])
     |> get_watchlist_data()}
  end

  def handle_event("search", %{"search" => query}, %{assigns: %{token: token}} = socket) do
    token_list =
      with true <- bit_size(query) > 0,
           {:ok, %{"data" => token_list}} <- API.search_token(token, "NSE", query) do
        token_list
        |> Enum.filter(&String.ends_with?(&1["tradingsymbol"], "-EQ"))
      else
        _ -> []
      end

    {:noreply, assign(socket, :token_list, token_list)}
  end

  def handle_event("toggle-token-watchlist", %{"token" => "17971"}, socket) do
    {:noreply, socket}
  end

  defp get_watchlist_data(socket) do
    socket
  end
end
