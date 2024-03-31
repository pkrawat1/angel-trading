defmodule ClientLoginLiveTest do
  use AngelTradingWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mock

  @valid_params %{
    "clientcode" => "clientcode",
    "password" => "password",
    "totp_secret" => "JBSWY3DPEHPK3PXP"
  }
  @invalid_params %{
    "clientcode" => "",
    "password" => "",
    "totp_secret" => ""
  }
  @session_params %{
    "clientcode" => "clientcode",
    "password" => "password",
    "totp_secret" => "JBSWY3DPEHPK3PXP",
    "token" => "jwtToken",
    "refresh_token" => "refreshToken",
    "feed_token" => "feedToken"
  }

  setup [:log_in_user]

  describe "renders the login form" do
    test "redirects to login if not logged in" do
      conn = get(build_conn(), ~p"/client/login")
      assert html_response(conn, 302)
      assert redirected_to(conn) == "/login"
    end

    test "renders the client login form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/client/login")
      assert html =~ "New Client"
    end
  end

  describe "handles client login" do
    test "redirects to client login when invalid credentials", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/client/login")

      assert view
             |> element("form")
             |> render_submit(%{"user" => @invalid_params}) =~ "Invalid credentials"
    end

    test "logs in the user", %{conn: conn} do
      with_mocks([
        {AngelTrading.TOTP, [], totp_now: fn _ -> {:ok, "123456"} end},
        {AngelTrading.API, [],
         login: fn _ ->
           {:ok,
            %{
              "data" => %{
                jwtToken: "jwtToken",
                feedToken: "feedToken",
                refreshToken: "refreshToken"
              }
            }}
         end}
      ]) do
        {:ok, view, html} = live(conn, ~p"/client/login")
        assert html =~ "New Client"

        assert view
               |> element("form")
               |> render_submit(%{"user" => @valid_params})

        assert_redirected(
          view,
          ~p</session/#{@session_params["clientcode"]}/#{@session_params["token"]}/#{@session_params["refresh_token"]}/#{@session_params["feed_token"]}/#{@session_params["password"]}/#{@session_params["totp_secret"]}>
        )
      end
    end
  end
end
