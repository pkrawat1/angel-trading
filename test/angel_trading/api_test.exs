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
    @token_response %{
      jwtToken: "jwtToken",
      refreshToken: "refreshToken",
      feedToken: "feedToken"
    }

    test "login/1" do
      with_mock API, login: fn _ -> {:ok, @token_response} end do
        {:ok, @token_response} = API.login(@valid_params)

        assert_called(
          API.login(
            :meck.is(fn params ->
              assert params == @valid_params
            end)
          )
        )
      end
    end

    test "logout/2" do
      with_mock API, logout: fn _, _ -> {:ok, %{}} end do
        API.logout("token", "clientcode")

        assert_called(API.logout("token", "clientcode"))
      end
    end

    test "generate_token/2" do
      with_mock API, generate_token: fn _, _ -> {:ok, @token_response} end do
        {:ok, @token_response} = API.generate_token("token", "refresh_token")

        assert_called(API.generate_token("token", "refresh_token"))
      end
    end
  end

  describe "Profile" do
    test "get_profile/1" do
      with_mock API, profile: fn _ -> {:ok, %{}} end do
        {:ok, _} = API.profile("token")

        assert_called(API.profile("token"))
      end
    end
  end
end
