defmodule AngelTrading.APITest do
  use ExUnit.Case

  import Tesla.Mock
  import AngelTrading.API

  describe "ntication: " do
    test "Login Success" do
      resp = %{
        "status" => true,
        "message" => "SUCCESS",
        "errorcode" => "",
        "data" => %{
          "jwtToken" => "token",
          "refreshToken" => "token",
          "feedToken" => "token"
        }
      }

      Tesla.Mock.mock(fn
        %{method: :post} -> json(resp)
      end)

      assert {:ok, body} = login(%{"clientcode" => "", "password" => "", "totp" => ""})
      assert body["message"] == "SUCCESS"
      assert body["data"] == resp["data"]
    end

    test "Login Failure" do
      resp = %{
        "data" => nil,
        "errorcode" => "AB1048",
        "message" => "Invalid clientcode parameter name",
        "status" => false
      }

      Tesla.Mock.mock(fn
        %{method: :post} -> json(resp)
      end)

      assert {:error, body} = login(%{"clientcode" => "", "password" => "", "totp" => ""})
      assert body["message"] == resp["message"]
    end
  end
end
