defmodule AngelTradingWeb.Components.BottomNav do
  use Phoenix.Component
  use AngelTradingWeb, :verified_routes
  import AngelTradingWeb.CoreComponents

  attr :client_code, :string

  def bottom_nav(assigns) do
    ~H"""
    <div class="fixed bottom-0 left-0 z-50 w-full h-16 bg-white border-t border-gray-200">
      <div class="grid h-full max-w-lg grid-cols-4 mx-auto font-medium">
        <.link
          navigate={~p"/"}
          type="button"
          class="inline-flex flex-col items-center justify-center px-5 hover:bg-gray-50 group"
        >
          <.icon name="hero-home-solid text-gray-500 w-6 h-6" />
          <span class="text-sm text-gray-500 group-hover:text-blue-600">Home</span>
        </.link>
        <.link
          :if={assigns[:client_code]}
          navigate={~p"/client/#{@client_code}/portfolio"}
          type="button"
          class="inline-flex flex-col items-center justify-center px-5 hover:bg-gray-50 group"
        >
          <.icon name="hero-folder-solid text-gray-500 w-6 h-6" />
          <span class="text-sm text-gray-500 group-hover:text-blue-600">Portfolio</span>
        </.link>
        <.link
          :if={assigns[:client_code]}
          navigate={~p"/client/#{@client_code}/orders"}
          type="button"
          class="inline-flex flex-col items-center justify-center px-5 hover:bg-gray-50 group"
        >
          <.icon name="hero-clipboard-solid text-gray-500 w-6 h-6" />
          <span class="text-sm text-gray-500 group-hover:text-blue-600">Orders</span>
        </.link>
        <.link
          navigate={~p"/client/login"}
          type="button"
          class="inline-flex flex-col items-center justify-center px-5 hover:bg-gray-50 group"
        >
          <.icon name="hero-user-plus-solid text-gray-500 w-6 h-6" />
          <span class="text-sm text-gray-500 group-hover:text-blue-600">Client</span>
        </.link>
      </div>
    </div>
    """
  end
end
