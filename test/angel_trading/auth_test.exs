defmodule AngelTrading.AuthTest do
  use ExUnit.Case

  import Tesla.Mock
  alias AngelTrading.Auth

  describe "Authentication: " do
    test "Login Success" do
      resp_json =
        json(%{
          "status" => true,
          "message" => "SUCCESS",
          "errorcode" => "",
          "data" => %{
            "jwtToken" => "token",
            "refreshToken" => "token",
            "feedToken" => "token"
          }
        })

      Tesla.Mock.mock(fn
        %{method: :post} ->
          %Tesla.Env{
            status: 200,
            body: resp_json
          }
      end)

      assert {:ok, env} = Auth.login("", "", "")
      assert env.status == 200
      assert env.body == resp_json
    end

    test "Login Failure" do
      resp_json =
        json(%{
          body: %{
            "data" => nil,
            "errorcode" => "AB1048",
            "message" => "Invalid clientcode parameter name",
            "status" => false
          }
        })

      Tesla.Mock.mock(fn
        %{method: :post} ->
          %Tesla.Env{
            status: 200,
            body: resp_json
          }
      end)

      assert {:ok, env} = Auth.login("", "", "")
      assert env.status == 200
      assert env.body == resp_json
    end
  end
end
