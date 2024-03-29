defmodule AngelTradingWeb.Router do
  use AngelTradingWeb, :router
  import AngelTradingWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_user_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AngelTradingWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AngelTradingWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :no_auth,
      on_mount: [{AngelTradingWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/login", LoginLive
    end

    get "/session/:user/:password/:totp", SessionController, :create
  end

  scope "/", AngelTradingWeb do
    pipe_through [:browser, :ensure_authenticated]

    delete "/session/logout", SessionController, :delete

    get "/session/:client_code/:token/:refresh_token/:feed_token/:pin/:totp_secret",
        SessionController,
        :client_create

    live_session :require_auth, on_mount: [{AngelTradingWeb.UserAuth, :ensure_authenticated}] do
      live "/client/login", ClientLoginLive
      live "/", DashboardLive
      live "/client/:client_code/watchlist", WatchlistLive, :index
      live "/client/:client_code/watchlist/quote", WatchlistLive, :quote
      live "/client/:client_code/portfolio", PortfolioLive, :show
      live "/client/:client_code/portfolio/quote", PortfolioLive, :quote
      live "/client/:client_code/orders", OrdersLive, :index
      live "/client/:client_code/orders/quote", OrdersLive, :quote
      live "/client/:client_code/order/new", OrderLive, :new
      live "/client/:client_code/order/edit", OrderLive, :edit
      live "/client/:client_code/ask", AskLive, :index
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", AngelTradingWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:angel_trading, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AngelTradingWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
