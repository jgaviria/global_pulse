defmodule GlobalPulseWeb.GaugeTestLive do
  @moduledoc """
  Simple test page to debug gauge system issues.
  """
  use GlobalPulseWeb, :live_view

  def mount(_params, _session, socket) do
    # Test if GaugeDataManager is running
    service_status = try do
      case GenServer.whereis(GlobalPulse.Services.GaugeDataManager) do
        pid when is_pid(pid) -> "GaugeDataManager is running (PID: #{inspect(pid)})"
        nil -> "GaugeDataManager is NOT running"
      end
    rescue
      error -> "Error checking GaugeDataManager: #{inspect(error)}"
    end

    # Try to get gauge data
    gauge_test = try do
      data = GlobalPulse.Services.GaugeDataManager.get_gauge_data(:sentiment)
      "Successfully got gauge data: #{inspect(data.category)}"
    rescue
      error -> "Error getting gauge data: #{inspect(error)}"
    end

    {:ok,
     socket
     |> assign(:page_title, "Gauge Test")
     |> assign(:service_status, service_status)
     |> assign(:gauge_test, gauge_test)
    }
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-white p-8">
      <h1 class="text-4xl font-bold mb-8">🧪 Gauge System Test</h1>
      
      <div class="space-y-6">
        <div class="p-4 bg-gray-800 rounded">
          <h2 class="text-xl font-semibold mb-4">Service Status</h2>
          <p><%= @service_status %></p>
        </div>

        <div class="p-4 bg-gray-800 rounded">
          <h2 class="text-xl font-semibold mb-4">Gauge Data Test</h2>
          <p><%= @gauge_test %></p>
        </div>

        <div class="p-4 bg-green-900 rounded">
          <h2 class="text-xl font-semibold mb-4">✅ Success</h2>
          <p>If you see this page, the basic LiveView is working properly!</p>
        </div>
      </div>
    </div>
    """
  end
end