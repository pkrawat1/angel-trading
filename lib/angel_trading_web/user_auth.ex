defmodule AngelTradingWeb.UserAuth do
  use AngelTradingWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller
  alias AngelTrading.Auth

  def login_in_user(conn, %{
        "token" => token,
        "refresh_token" => refresh_token,
        "feed_token" => feed_token
      }) do
    conn
    |> put_session(:token, token)
    |> put_session(:refresh_token, refresh_token)
    |> put_session(:feed_token, feed_token)
    |> configure_session(renew: true)
    |> redirect(to: "/")
  end

  def ensure_authenticated(conn, _opts) do
    with {:ok, _} <- Auth.profile(get_session(conn, :token)) do
      conn
    else
      {:error, message} ->
        conn
        |> put_flash(:error, "You must log in to access this page.")
        |> redirect(to: ~p"/login")
        |> halt()
    end
  end

  def redirect_if_user_is_authenticated(conn, _opts) do
    with {:ok, _} <- Auth.profile(get_session(conn, :token)) do
      conn
      |> put_flash(:error, "You need to log out to view this page.")
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      {:error, _} ->
        conn
    end
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    with {:ok, _} <- Auth.profile(session["token"]) do
      {:cont, socket}
    else
      {:error, message} ->
        {:halt,
         socket
         |> Phoenix.LiveView.put_flash(:error, message)
         |> Phoenix.LiveView.redirect(to: ~p"/login")}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    with {:ok, _} <- Auth.profile(session["token"]) do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:error, _} ->
        {:cont, socket}
    end
  end

  defp signed_in_path(_conn), do: ~p"/"
end
