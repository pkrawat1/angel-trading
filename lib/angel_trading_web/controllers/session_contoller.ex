defmodule AngelTradingWeb.SessionController do
  use AngelTradingWeb, :controller

  alias AngelTradingWeb.UserAuth

  defdelegate create(conn, params), to: UserAuth, as: :login_user
  defdelegate delete(conn, params), to: UserAuth, as: :logout_user
  defdelegate client_create(conn, params), to: UserAuth, as: :login_client
end
