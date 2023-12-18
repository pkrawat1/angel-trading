defmodule AngelTradingWeb.LoginLive do
  use AngelTradingWeb, :live_view

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
        <.input required field={f[:user]} value={@params["user"]} placeholder="User" />
        <.input
          field={f[:password]}
          type="password"
          value={@params["password"]}
          placeholder="Password"
          maxlength="32"
          minlength="8"
          required
        />
        <.input
          required
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

  def handle_event(
        "login",
        %{"user" => %{"user" => user, "password" => password, "totp" => totp}},
        socket
      )
      when bit_size(user) != 0 and bit_size(password) != 0 and bit_size(totp) != 0 do
    {:noreply, redirect(socket, to: ~p"/session/#{user}/#{password}/#{totp}")}
  end

  def handle_event("login", %{"user" => params}, socket) do
    {
      :noreply,
      socket
      |> push_patch(to: ~p"/login?#{params}")
      |> put_flash(:error, "Invalid credentials")
    }
  end
end
