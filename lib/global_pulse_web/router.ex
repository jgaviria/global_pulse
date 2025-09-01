defmodule GlobalPulseWeb.Router do
  use GlobalPulseWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GlobalPulseWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GlobalPulseWeb do
    pipe_through :browser

    live "/", DashboardLive.Index, :index
    live "/financial", FinancialLive.Index, :index
    live "/news", NewsLive.Index, :index
    live "/trends", TrendsLive.Index, :index
    live "/natural", NaturalEventsLive.Index, :index
    live "/anomalies", AnomaliesLive.Index, :index
  end

  if Application.compile_env(:global_pulse, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GlobalPulseWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end