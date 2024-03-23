defmodule AngelTrading.APITest do
  use ExUnit.Case, async: true
  alias AngelTrading.API
  import Mock

  describe "Auth" do
    @valid_params %{
      "clientcode" => "clientcode",
      "password" => "password",
      "totp" => "totp"
    }
    test "login" do
      with_mock API, login: fn _ -> {:ok, %{token: ""}} end do
        API.login(@valid_params)

        assert_called(
          API.login(
            :meck.is(fn params ->
              assert params == @valid_params
            end)
          )
        )
      end
    end
  end
end
