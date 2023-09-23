defmodule AngelTradingWeb.LoginLive do
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
        <.input
          field={f[:totp]}
          value={@params["totp"]}
          placeholder="Totp"
          maxlength="6"
          minlength="6"
        />
        <:actions>
          <.button class="w-full">Login</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def handle_event("login", %{"user" => params}, socket) do
    with {:ok,
          %{
            "data" => %{
              "jwtToken" => token,
              "refreshToken" => refresh_token,
              "feedToken" => feed_token
            }
          }} <-
           API.login(params) do
      clientcode = params["clientcode"]
      {:noreply, redirect(socket, to: ~p"/session/#{clientcode}/#{token}/#{refresh_token}/#{feed_token}")}
    else
      {:error, %{"message" => message}} ->
        {
          :noreply,
          socket
          |> push_patch(to: ~p"/login?#{params}")
          |> put_flash(:error, message)
        }
    end
  end
end
