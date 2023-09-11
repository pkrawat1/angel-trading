defmodule AngelTradingWeb.LoginLive do
  use AngelTradingWeb, :live_view
  alias AngelTrading.Auth

  def mount(params, _session, socket) do
    {:ok, assign(socket, params: params["users"])}
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
          %{data: %{"token" => token, "refreshToken" => refresh_token, "feedToken" => feed_token}}} <-
           Auth.login(params) do
      {:stop, redirect(socket, to: ~p"/session/#{token}/#{refresh_token}/#{feed_token}")}
    else
      {:error, %{"message" => message}} ->
        {
          :noreply,
          put_flash(socket, :error, message)
        }
    end
  end
end
