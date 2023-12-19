defmodule AngelTradingWeb.Components.BottomNav do
  use Phoenix.Component
  use AngelTradingWeb, :verified_routes
  import AngelTradingWeb.CoreComponents

  attr :client_code, :string

  def bottom_nav(assigns) do
    ~H"""
    <div class="fixed bottom-0 left-0 z-50 w-full h-14 bg-white border-t border-gray-200">
      <div class="flex h-full justify-center space-x-6 mx-auto text-xs uppercase">
        <.link
          navigate={~p"/"}
          type="button"
          class="inline-flex flex-col items-center justify-center group"
        >
          <.icon name="hero-home-solid w-4 h-4 text-gray-500 group-hover:text-blue-600" />
          <span class="text-gray-500 group-hover:text-blue-600">Home</span>
        </.link>
        <.link
          navigate={~p"/watchlist"}
          type="button"
          class="inline-flex flex-col items-center justify-center group"
        >
          <.icon name="hero-star-solid w-4 h-4 text-gray-500 group-hover:text-blue-600" />
          <span class="text-gray-500 group-hover:text-blue-600">Watchlist</span>
        </.link>
        <.link
          :if={assigns[:client_code]}
          navigate={~p"/client/#{@client_code}/portfolio"}
          type="button"
          class="inline-flex flex-col items-center justify-center group"
        >
          <.icon name="hero-folder-solid w-4 h-4 text-gray-500 group-hover:text-blue-600" />
          <span class="text-gray-500 group-hover:text-blue-600">Portfolio</span>
        </.link>
        <.link
          :if={assigns[:client_code]}
          navigate={~p"/client/#{@client_code}/orders"}
          type="button"
          class="inline-flex flex-col items-center justify-center group"
        >
          <.icon name="hero-clipboard-solid w-4 h-4 text-gray-500 group-hover:text-blue-600" />
          <span class="text-gray-500 group-hover:text-blue-600">Orders</span>
        </.link>
        <.link
          navigate={~p"/client/login"}
          type="button"
          class="inline-flex flex-col items-center justify-center group"
        >
          <.icon name="hero-user-plus-solid w-4 h-4 text-gray-500 group-hover:text-blue-600" />
          <span class="text-gray-500 group-hover:text-blue-600">Client</span>
        </.link>
      </div>
    </div>
    """
  end
end
