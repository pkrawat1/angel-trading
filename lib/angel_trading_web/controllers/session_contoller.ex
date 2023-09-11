defmodule AngelTradingWeb.SessionController do
  use AngelTradingWeb, :controller

  def create(conn, %{
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
end
