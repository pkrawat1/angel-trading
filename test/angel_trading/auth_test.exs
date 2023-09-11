defmodule AngelTrading.AuthTest do
  use ExUnit.Case

  import Tesla.Mock
  alias AngelTrading.Auth

  describe "Authentication: " do
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
        %{method: :post} ->
          %Tesla.Env{
            status: 200,
            body: json(resp)
          }
      end)

      assert {:ok, body} = Auth.login("", "", "")
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
        %{method: :post} ->
          %Tesla.Env{
            status: 200,
            body: json(resp)
          }
      end)

      assert {:error, body} = Auth.login("", "", "")
      assert body["message"] == resp["message"]
    end
  end
end
