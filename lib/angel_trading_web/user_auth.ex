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
    |> put_session(
      :session_expiry,
      Timex.now("Asia/Calcutta")
      |> Timex.shift(days: 1)
      |> Timex.beginning_of_day()
      |> Timex.shift(hours: 5)
    )
    |> configure_session(renew: true)
    |> redirect(to: "/")
  end

  def ensure_authenticated(conn, _opts) do
    if session_valid?(get_session(conn)) do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  def redirect_if_user_is_authenticated(conn, _opts) do
    if session_valid?(get_session(conn)) do
      conn
      |> put_flash(:error, "You need to log out to view this page.")
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    if session_valid?(session) do
      {:cont, socket}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
       |> Phoenix.LiveView.redirect(to: ~p"/login")}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    if session_valid?(session) do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp signed_in_path(_conn), do: ~p"/"

  defp session_valid?(%{"session_expiry" => session_expiry}),
    do: Timex.after?(session_expiry, Timex.now("Asia/Kolkata"))

  defp session_valid?(session), do: false
end
