defmodule AngelTradingWeb.SessionController do
  use AngelTradingWeb, :controller

  alias AngelTradingWeb.UserAuth

  defdelegate create(conn, params), to: UserAuth, as: :login_in_user
end
