defmodule ClientLoginLiveTest do
  use AngelTradingWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mock

  setup %{conn: conn} do
    conn = get(conn, "/login")

    {:ok, conn: conn}
  end

  describe "renders the login form" do
    test "redirects to login if not logged in", %{conn: conn} do
      conn = get(conn, ~p"/client/login")
      assert html_response(conn, 302)
      assert redirected_to(conn) == "/login" 
    end

    setup [:log_in_user]
    test "renders the client login form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/client/login")
      assert html =~ "LOGIN"
    end
  end
end
