defmodule GlobalPulse.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Cachex, name: :global_cache},
      GlobalPulse.DataStore,
      GlobalPulse.StreamSupervisor,
      {GlobalPulse.Services.GaugeDataManager, []},
      {GlobalPulse.FinancialMonitor, []},
      {GlobalPulse.NewsMonitor, []},
      {GlobalPulse.NaturalEventsMonitor, []},
      {GlobalPulse.GoogleTrendsMonitor, []},
      GlobalPulse.MLPipeline,
      GlobalPulse.InflectionDetector,
      GlobalPulseWeb.Telemetry,
      {Phoenix.PubSub, name: GlobalPulse.PubSub},
      GlobalPulseWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: GlobalPulse.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    GlobalPulseWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
