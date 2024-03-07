defmodule AngelTradingWeb.Components.BottomNav do
  use Phoenix.Component
  use AngelTradingWeb, :verified_routes
  import AngelTradingWeb.CoreComponents

  attr :client_code, :string
  attr :active_page, :atom

  def bottom_nav(assigns) do
    ~H"""
    <div class="fixed bottom-0 left-0 z-50 w-full h-14 bg-white border-t border-gray-200 dark:bg-gray-900 dark:border-gray-800">
      <div class="flex h-full justify-center space-x-6 mx-auto text-xs uppercase">
        <.link
          navigate={~p"/"}
          type="button"
          class="inline-flex flex-col items-center justify-center group"
        >
          <.icon name={"hero-home-solid w-4 h-4 #{active_page_class(assigns, :home)}"} />
          <span class={active_page_class(assigns, :home)}>Home</span>
        </.link>
        <.link
          :if={assigns[:client_code]}
          navigate={~p"/client/#{@client_code}/watchlist"}
          type="button"
          class="inline-flex flex-col items-center justify-center group"
        >
          <.icon name={"hero-star-solid w-4 h-4 #{active_page_class(assigns, :watchlist)}"} />
          <span class={active_page_class(assigns, :watchlist)}>Watchlist</span>
        </.link>
        <.link
          :if={assigns[:client_code]}
          navigate={~p"/client/#{@client_code}/portfolio"}
          type="button"
          class="inline-flex flex-col items-center justify-center group"
        >
          <.icon name={"hero-folder-solid w-4 h-4 #{active_page_class(assigns, :portfolio)}"} />
          <span class={active_page_class(assigns, :portfolio)}>Portfolio</span>
        </.link>
        <.link
          :if={assigns[:client_code]}
          navigate={~p"/client/#{@client_code}/orders"}
          type="button"
          class="inline-flex flex-col items-center justify-center group"
        >
          <.icon name={"hero-clipboard-solid w-4 h-4 #{active_page_class(assigns, :orders)}"} />
          <span class={active_page_class(assigns, :orders)}>Orders</span>
        </.link>
        <.link
          navigate={~p"/client/login"}
          type="button"
          class="inline-flex flex-col items-center justify-center group"
        >
          <.icon name={"hero-user-plus-solid w-4 h-4 #{active_page_class(assigns, :client)}"} />
          <span class={active_page_class(assigns, :client)}>Client</span>
        </.link>
        <.link
          :if={assigns[:client_code]}
          navigate={~p"/client/#{@client_code}/ask"}
          type="button"
          class="inline-flex flex-col items-center justify-center group"
        >
          <.icon name={"hero-chat-bubble-left-ellipsis-solid w-4 h-4 #{active_page_class(assigns, :ask)}"} />
          <span class={active_page_class(assigns, :ask)}>Ask</span>
        </.link>
      </div>
    </div>
    """
  end

  defp active_page_class(%{active_page: active_page}, page) when page == active_page,
    do: "text-red-500 group-hover:text-red-500"

  defp active_page_class(_, _), do: "text-gray-500 group-hover:text-red-500"
end
