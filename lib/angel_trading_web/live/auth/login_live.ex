defmodule AngelTradingWeb.LoginLive do
  use AngelTradingWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex justify-center">
      <.simple_form :let={f} for={%{}}>
        <.input field={f[:client_code]} placeholder="Client code" />
        <.input field={f[:password]} placeholder="Pin" />
        <.input field={f[:totp]} placeholder="Totp" />
        <:actions>
          <.button class="w-full">Login</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
