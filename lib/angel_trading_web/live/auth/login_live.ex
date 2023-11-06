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
        <.input field={f[:user]} value={@params["user"]} placeholder="User" />
        <.input
          field={f[:password]}
          type="password"
          value={@params["password"]}
          placeholder="Password"
          maxlength="8"
          minlength="8"
        />
        <:actions>
          <.button class="w-full">Login</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def handle_event("login", %{"user" => %{"user" => user, "password" => password}}, socket) do
    {:noreply, redirect(socket, to: ~p"/session/#{user}/#{password}")}
  end
end
