defmodule SlayPlayWeb.Router do
  use SlayPlayWeb, :router

  import SlayPlayWeb.BasicAuth, only: [redirect_if_authenticated: 2]

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {SlayPlayWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SlayPlayWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    post "/session", SignInController, :new

    get "/signin", SignInController, :index
  end

  scope "/", SlayPlayWeb do
    pipe_through :browser

    live "/", HomeLive.Home, :index

    get "/files/:type/:id", FileController, :show

    live_session :admin, on_mount: [{SlayPlayWeb.BasicAuth, :ensure_authenticated}] do
      live "/admin", AdminLive.Index, :index
      live "/admin/songs", AdminLive.Songs, :index
      live "/admin/songs/new", AdminLive.Songs, :new
      live "/admin/slides", AdminLive.Slides, :index
      live "/admin/slides/new", AdminLive.Slides, :new
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", SlayPlayWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SlayPlayWeb.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
