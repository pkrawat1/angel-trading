defmodule AngelTradingWeb.ClientLoginLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.API

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _url, socket) do
    {:noreply, assign(socket, params: params)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex justify-center">
      <.simple_form :let={f} for={%{}} as={:user} autocomplete="off" phx-submit="login">
        <.input field={f[:clientcode]} value={@params["clientcode"]} placeholder="Client code" />
        <.input
          field={f[:password]}
          type="password"
          value={@params["password"]}
          placeholder="Pin"
          maxlength="4"
          minlength="4"
        />
        <.input field={f[:totp_secret]} value={@params["totp_secret"]} placeholder="Totp secret" />
        <:actions>
          <.button class="w-full">Login</.button>
        </:actions>
      </.simple_form>
      <.bottom_nav />
    </div>
    """
  end

  def handle_event(
        "login",
        %{
          "user" =>
            %{"clientcode" => clientcode, "password" => password, "totp_secret" => totp_secret} =
              params
        },
        socket
      ) do
    with {:ok, totp} <- AngelTrading.TOTP.totp_now(params["totp_secret"]),
         {:ok,
          %{
            "data" => %{
              "jwtToken" => token,
              "refreshToken" => refresh_token,
              "feedToken" => feed_token
            }
          }} <-
           API.login(%{
             "clientcode" => clientcode,
             "password" => password,
             "totp" => totp
           }) do
      clientcode = params["clientcode"]

      {:noreply,
       redirect(socket,
         to:
           ~p"/session/#{clientcode}/#{token}/#{refresh_token}/#{feed_token}/#{password}/#{totp_secret}"
       )}
    else
      {:error, error} ->
        message =
          case error do
            <<message::binary>> -> message
            %{"message" => message} -> message
          end

        {
          :noreply,
          socket
          |> push_patch(to: ~p"/client/login?#{params}")
          |> put_flash(:error, message)
        }
    end
  end
end
