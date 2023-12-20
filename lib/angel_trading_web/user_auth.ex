defmodule AngelTradingWeb.UserAuth do
  use AngelTradingWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller
  alias AngelTrading.{Account, API, Utils}
  require Logger

  @remember_me_cookie "_angel_remember_me"
  @remember_me_options [sign: true, same_site: "Lax"]
  @session_valid_days 3

  def login_user(conn, %{
        "user" => user,
        "password" => password,
        "totp" => totp
      }) do
    with {:ok, %{body: %{"totp_secret" => totp_secret}}} <-
           user |> create_user_hash(password) |> Account.get_user(),
         {:ok, totp_secret} <-
           Utils.decrypt(:totp_secret, totp_secret),
         :ok <- AngelTrading.TOTP.valid?(totp_secret, totp) do
      conn
      |> put_in_session(user, password)
      |> put_flash(:info, "logged in successfully.")
      |> redirect(to: "/")
    else
      {:ok, %{body: nil}} ->
        conn
        |> put_flash(:error, "Invalid credentials or User not active.")
        |> redirect(to: ~p"/login")
        |> halt()

      {:error, :invalid_totp} ->
        conn
        |> put_flash(:error, "Invalid totp. Please try again.")
        |> redirect(to: ~p"/login?user=#{user}&password=#{password}")
        |> halt()
    end
  end

  def login_client(conn, %{
        "client_code" => client_code,
        "token" => token,
        "refresh_token" => refresh_token,
        "feed_token" => feed_token,
        "pin" => pin,
        "totp_secret" => totp_secret
      }) do
    case(
      conn
      |> get_session(:user_hash)
      |> Account.set_tokens(%{
        "client_code" => client_code,
        "token" => token,
        "refresh_token" => refresh_token,
        "feed_token" => feed_token,
        "pin" => pin,
        "totp_secret" => totp_secret
      })
    ) do
      :ok ->
        conn
        |> put_flash(:info, "Client logged in successfully.")
        |> redirect(to: ~p"/")

      :error ->
        conn
        |> put_flash(:error, "Unable to login at the moment. Please try again.")
        |> redirect(to: ~p"/client/login")
        |> halt()
    end

    conn
    |> redirect(to: "/")
  end

  def logout_user(conn, _params) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> put_flash(:info, "logged out successfully.")
    |> redirect(to: ~p"/login")
  end

  def fetch_user_session(conn, _opts) do
    if get_session(conn, :user) do
      conn
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      with [user, password] <-
             String.split(conn.cookies[@remember_me_cookie] || "", "|") do
        put_in_session(conn, user, password)
      else
        _ ->
          conn
      end
    end
    |> assign(:current_user, get_session(conn, :user))
  end

  defp put_in_session(conn, user, password) do
    user_hash = create_user_hash(user, password)

    user_hash
    |> Account.get_client_codes()
    |> case do
      {:ok, %{body: data}} when is_map(data) -> Map.values(data)
      _ -> []
    end
    |> Enum.map(fn client_code ->
      with {:ok, %{body: data}} when is_binary(data) <- Account.get_client(client_code),
           {:ok, %{pin: pin, totp_secret: totp_secret}} <-
             Utils.decrypt(:client_tokens, data),
           {:ok, totp} <- AngelTrading.TOTP.totp_now(totp_secret),
           {:ok,
            %{
              "data" => %{
                "jwtToken" => token,
                "refreshToken" => refresh_token,
                "feedToken" => feed_token
              }
            }} <-
             API.login(%{
               "clientcode" => client_code,
               "password" => pin,
               "totp" => totp
             }),
           :ok <-
             Account.set_tokens(user_hash, %{
               "client_code" => client_code,
               "token" => token,
               "refresh_token" => refresh_token,
               "feed_token" => feed_token,
               "pin" => pin,
               "totp_secret" => totp_secret
             }) do
        Logger.info("User client[#{client_code}] tokens refreshed")
      else
        e ->
          Logger.error("[UserAuth] Unable to refresh client[#{client_code}] tokens.")
          IO.inspect(e)
      end
    end)

    conn
    |> configure_session(renew: true)
    |> clear_session()
    |> put_session(:user, user)
    |> put_session(:password, password)
    |> put_session(:user_hash, user_hash)
    |> put_session(:session_expiry, session_valid_till())
    |> put_resp_cookie(
      @remember_me_cookie,
      user <> "|" <> password,
      [
        {:max_age, Timex.diff(session_valid_till(), now(), :seconds)}
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
    socket = mount_current_user(session, socket)

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
    socket = mount_current_user(session, socket)

    if session_valid?(session) do
      {:halt, Phoenix.LiveView.redirect(socket, to: signed_in_path(socket))}
    else
      {:cont, socket}
    end
  end

  defp mount_current_user(session, socket) do
    Phoenix.Component.assign_new(socket, :current_user, fn -> session["user"] end)
  end

  defp signed_in_path(_conn), do: ~p"/"

  defp session_valid?(%{"session_expiry" => session_expiry}),
    do: Timex.after?(session_expiry, now())

  defp session_valid?(_session), do: false

  defp session_valid_till() do
    now()
    |> Timex.shift(days: @session_valid_days)
    |> Timex.beginning_of_day()
  end

  defp now(), do: Timex.now("Asia/Kolkata")

  defp create_user_hash(user, password),
    do: :sha256 |> :crypto.hash(user <> "|" <> password) |> Base.encode64()
end
