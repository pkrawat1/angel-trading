defmodule AngelTrading.APITest do
  use ExUnit.Case, async: true
  alias AngelTrading.API
  import Mock

  describe "Auth" do
    test "login" do
      with_mock API, login: fn _ -> {:ok, %{token: ""}} end do
        API.login(%{
          "clientcode" => "clientcode",
          "password" => "password",
          "totp" => "totp"
        })

        assert_called(
          API.login(
            :meck.is(fn params ->
              assert params == %{
                       "clientcode" => "clientcode",
                       "password" => "password",
                       "totp" => "totp"
                     }
            end)
          )
        )
      end
    end
  end
end
