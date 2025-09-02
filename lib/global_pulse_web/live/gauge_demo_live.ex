defmodule GlobalPulseWeb.GaugeDemoLive do
  @moduledoc """
  Demo page for the comprehensive real-time gauge system.
  
  Shows all gauge categories in action:
  - Sentiment: Real-time global news sentiment from NewsMonitor
  - Financial: Market sentiment (placeholder data)
  - Natural Events: Seismic activity severity (placeholder data)  
  - Social Trends: Social media trends (placeholder data)
  """
  use GlobalPulseWeb, :live_view
  require Logger

  def mount(_params, _session, socket) do
    # Subscribe to gauge updates for real-time data
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "gauge_updates")
      # Also subscribe to news updates to show coordination
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "news_updates")
    end
    
    {:ok,
     socket
     |> assign(:page_title, "Gauge System Demo")
     |> assign(:last_news_update, nil)
     |> assign(:demo_mode, true)
    }
  end

  def handle_info({:gauge_update, category, _gauge_data}, socket) do
    Logger.info("🎯 GAUGE DEMO: Received gauge update for #{category}")
    {:noreply, socket}
  end

  def handle_info({:news_update, _data}, socket) do
    {:noreply, assign(socket, :last_news_update, DateTime.utc_now())}
  end

  def handle_event("simulate_financial", _params, socket) do
    # Simulate financial market data update
    financial_value = 45 + :rand.uniform() * 30  # Random value between 45-75
    
    GlobalPulse.Services.GaugeDataManager.update_value(
      :financial,
      financial_value,
      %{confidence: 0.8, source: "demo_simulation"}
    )
    
    {:noreply, socket}
  end

  def handle_event("simulate_natural_events", _params, socket) do
    # Simulate natural events data update  
    severity = 1.0 + :rand.uniform() * 4.0  # Random severity 1.0-5.0
    
    GlobalPulse.Services.GaugeDataManager.update_value(
      :natural_events,
      severity,
      %{confidence: 0.9, source: "demo_simulation", event_type: "seismic"}
    )
    
    {:noreply, socket}
  end

  def handle_event("simulate_social_trends", _params, socket) do
    # Simulate social trends data update
    trend_value = 30 + :rand.uniform() * 40  # Random value between 30-70
    
    GlobalPulse.Services.GaugeDataManager.update_value(
      :social_trends,
      trend_value,
      %{confidence: 0.7, source: "demo_simulation"}
    )
    
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-950 text-white">
      <div class="container mx-auto px-4 py-8">
        
        <!-- Page Header -->
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-white mb-4">
            🎯 Global Pulse Gauge System
          </h1>
          <p class="text-lg text-gray-300 mb-6">
            Real-time monitoring gauges with historical baselines and smooth animations
          </p>
          
          <%= if @last_news_update do %>
            <div class="inline-flex items-center space-x-2 bg-blue-900/20 border border-blue-700/30 rounded px-4 py-2">
              <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
              <span class="text-sm text-blue-200">
                Live news data updated <%= time_ago(@last_news_update) %>
              </span>
            </div>
          <% end %>
        </div>
        
        <!-- Gauge Grid -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          
          <!-- Sentiment Gauge - Real Data from NewsMonitor -->
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <h2 class="text-xl font-semibold text-green-400">Global Sentiment</h2>
              <div class="flex items-center space-x-2 text-sm text-gray-400">
                <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                <span>Live Data</span>
              </div>
            </div>
            <.live_component 
              module={GlobalPulseWeb.GaugeComponent}
              id="sentiment-gauge"
              category={:sentiment}
            />
          </div>
          
          <!-- Financial Gauge - Demo Data -->
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <h2 class="text-xl font-semibold text-purple-400">Financial Pulse</h2>
              <button 
                phx-click="simulate_financial"
                class="px-3 py-1 bg-purple-600 hover:bg-purple-700 rounded text-sm font-medium transition-colors"
              >
                Simulate Update
              </button>
            </div>
            <.live_component 
              module={GlobalPulseWeb.GaugeComponent}
              id="financial-gauge"
              category={:financial}
            />
          </div>
          
          <!-- Natural Events Gauge - Demo Data -->
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <h2 class="text-xl font-semibold text-orange-400">Natural Events</h2>
              <button 
                phx-click="simulate_natural_events"
                class="px-3 py-1 bg-orange-600 hover:bg-orange-700 rounded text-sm font-medium transition-colors"
              >
                Simulate Update
              </button>
            </div>
            <.live_component 
              module={GlobalPulseWeb.GaugeComponent}
              id="natural-events-gauge"
              category={:natural_events}
            />
          </div>
          
          <!-- Social Trends Gauge - Demo Data -->
          <div class="space-y-4">
            <div class="flex items-center justify-between">
              <h2 class="text-xl font-semibold text-pink-400">Social Trends</h2>
              <button 
                phx-click="simulate_social_trends"
                class="px-3 py-1 bg-pink-600 hover:bg-pink-700 rounded text-sm font-medium transition-colors"
              >
                Simulate Update
              </button>
            </div>
            <.live_component 
              module={GlobalPulseWeb.GaugeComponent}
              id="social-trends-gauge"
              category={:social_trends}
            />
          </div>
          
        </div>
        
        <!-- System Status -->
        <div class="bg-gray-900 rounded-lg p-6 border border-gray-700">
          <h3 class="text-lg font-semibold text-white mb-4">System Status</h3>
          <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div class="bg-gray-800 rounded p-4">
              <div class="flex items-center space-x-2">
                <div class="w-3 h-3 bg-green-500 rounded-full"></div>
                <span class="text-sm font-medium text-green-400">News Monitor</span>
              </div>
              <p class="text-xs text-gray-400 mt-1">Real-time sentiment analysis</p>
            </div>
            
            <div class="bg-gray-800 rounded p-4">
              <div class="flex items-center space-x-2">
                <div class="w-3 h-3 bg-blue-500 rounded-full"></div>
                <span class="text-sm font-medium text-blue-400">Gauge System</span>
              </div>
              <p class="text-xs text-gray-400 mt-1">Historical baselines & trends</p>
            </div>
            
            <div class="bg-gray-800 rounded p-4">
              <div class="flex items-center space-x-2">
                <div class="w-3 h-3 bg-purple-500 rounded-full"></div>
                <span class="text-sm font-medium text-purple-400">PubSub</span>
              </div>
              <p class="text-xs text-gray-400 mt-1">Real-time updates</p>
            </div>
            
            <div class="bg-gray-800 rounded p-4">
              <div class="flex items-center space-x-2">
                <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
                <span class="text-sm font-medium text-yellow-400">ApexCharts</span>
              </div>
              <p class="text-xs text-gray-400 mt-1">Smooth animations</p>
            </div>
          </div>
        </div>
        
        <!-- Technical Details -->
        <div class="mt-8 bg-blue-900/20 border border-blue-700/30 rounded-lg p-6">
          <h3 class="text-lg font-semibold text-blue-400 mb-4">Technical Implementation</h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6 text-sm text-blue-200">
            <div>
              <h4 class="font-medium text-blue-300 mb-2">Frontend Features</h4>
              <ul class="space-y-1">
                <li>• ApexCharts radial gauges with smooth animations</li>
                <li>• Real-time PubSub updates via Phoenix channels</li>
                <li>• Historical baseline indicators (7-day, 30-day)</li>
                <li>• Trend detection and confidence scoring</li>
                <li>• Responsive design with Tailwind CSS</li>
              </ul>
            </div>
            <div>
              <h4 class="font-medium text-blue-300 mb-2">Backend Services</h4>
              <ul class="space-y-1">
                <li>• GaugeDataManager GenServer with state persistence</li>
                <li>• Exponential smoothing for reactivity</li>
                <li>• Multi-category support (sentiment, financial, etc.)</li>
                <li>• Bias-aware sentiment analysis integration</li>
                <li>• Automatic baseline recalculation</li>
              </ul>
            </div>
          </div>
        </div>
        
      </div>
    </div>
    """
  end

  defp time_ago(datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)
    
    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> "#{div(diff_seconds, 86400)}d ago"
    end
  end
end