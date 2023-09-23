defmodule AngelTradingWeb.UserAuth do
  use AngelTradingWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  @remember_me_cookie "_angel_remember_me"
  @remember_me_options [sign: true, same_site: "Lax"]

  def login_in_user(conn, %{
        "client_code" => client_code,
        "token" => token,
        "refresh_token" => refresh_token,
        "feed_token" => feed_token
      }) do
    conn
    |> put_tokens_in_session(token, refresh_token, feed_token, client_code)
    |> redirect(to: "/")
  end

  def fetch_user_session(conn, _opts) do
    # if get_session(conn, :token) do
      # conn
    # else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      with [token, refresh_token, feed_token, client_code] <-
             String.split(conn.cookies[@remember_me_cookie] || "", "|") do
        put_tokens_in_session(conn, token, refresh_token, feed_token, client_code)
      else
        _ ->
          conn
      end
    # end
  end

  defp put_tokens_in_session(conn, token, refresh_token, feed_token, client_code) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> put_session(:client_code, client_code)
    |> put_session(:token, token)
    |> put_session(:refresh_token, refresh_token)
    |> put_session(:feed_token, feed_token)
    |> put_session(
      :session_expiry,
      session_valid_till()
    )
    |> put_resp_cookie(
      @remember_me_cookie,
      token <> "|" <> refresh_token <> "|" <> feed_token <> "|" <> client_code,
      [
        {:max_age, Timex.diff(session_valid_till(), Timex.now("Asia/Kolkata"), :seconds)}
        | @remember_me_options
      ]
    )
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

  defp session_valid?(_session), do: false

  defp session_valid_till(),
    do:
      Timex.now("Asia/Calcutta")
      |> Timex.shift(days: 1)
      |> Timex.beginning_of_day()
      |> Timex.shift(hours: 5)
end
