defmodule AngelTradingWeb.LoginLiveTest do
  use AngelTradingWeb.ConnCase
  import Phoenix.LiveViewTest
  import Mock
  alias AngelTrading.TOTP

  @valid_params %{
    "user" => "user",
    "password" => "password",
    "totp" => "123456"
  }
  @invalid_params %{
    "user" => "",
    "password" => "",
    "totp" => ""
  }
  @session_params %{
    "user" => "user",
    "password" => "password",
    "totp" => "123456"
  }

  test "renders the login form", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/login")
    assert html =~ "LOGIN"
  end

  test "redirects to login when invalid credentials", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/login")

    assert view
           |> element("form")
           |> render_submit(%{"user" => @invalid_params}) =~ "Invalid credentials"
  end

  test "redirects to session when valid credentials", %{conn: conn} do
    with_mock TOTP, valid?: fn _, _ -> :ok end do
      {:ok, view, _html} = live(conn, ~p"/login")

      assert view
             |> element("form")
             |> render_submit(%{"user" => @valid_params})
             |> follow_redirect(conn)

      flash =
        assert_redirected(
          view,
          ~p"/session/#{@session_params["user"]}/#{@session_params["password"]}/#{@session_params["totp"]}"
        )
    end
  end
end
