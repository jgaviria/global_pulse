defmodule GlobalPulseWeb.GaugeComponent do
  @moduledoc """
  Reusable real-time gauge component with historical baselines and smooth animations.
  
  Uses ApexCharts for smooth gauge visualization and integrates with GaugeDataManager
  for real-time data updates via PubSub.
  
  Supports all categories: sentiment, financial, natural_events, social_trends
  """
  use GlobalPulseWeb, :live_component
  require Logger

  def mount(socket) do
    {:ok, socket}
  end

  def update(%{category: category} = assigns, socket) do
    # Subscribe to gauge updates for this category
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "gauge_updates")
    end
    
    # Get initial gauge data with error handling
    gauge_data = case GlobalPulse.Services.GaugeDataManager.get_gauge_data(category) do
      %GlobalPulse.Services.GaugeDataManager.GaugeData{} = data -> data
      _ -> 
        Logger.warning("🎯 GaugeComponent: Could not get data for #{category}, using fallback")
        create_fallback_gauge_data(category)
    end
    
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:gauge_data, gauge_data)
     |> assign(:chart_id, "gauge-#{category}-#{System.unique_integer([:positive])}")
    }
  rescue
    error ->
      Logger.error("🎯 GaugeComponent: Error updating component: #{inspect(error)}")
      gauge_data = create_fallback_gauge_data(category)
      {:ok,
       socket
       |> assign(assigns)
       |> assign(:gauge_data, gauge_data)
       |> assign(:chart_id, "gauge-#{category}-#{System.unique_integer([:positive])}")
      }
  end

  def handle_info({:gauge_update, category, gauge_data}, socket) do
    # Only update if this is our category
    if category == socket.assigns.category do
      {:noreply, 
       socket
       |> assign(:gauge_data, gauge_data)
       |> push_event("update_gauge", %{
         chart_id: socket.assigns.chart_id,
         value: gauge_data.smoothed_value,
         baseline_7d: gauge_data.baseline_7d,
         baseline_30d: gauge_data.baseline_30d,
         trend: gauge_data.trend_direction,
         trend_strength: gauge_data.trend_strength,
         confidence: gauge_data.confidence,
         colors: gauge_colors(gauge_data)
       })
      }
    else
      {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="relative overflow-hidden">
      <!-- Modern Glass Card Background -->
      <div class="absolute inset-0 bg-gradient-to-br from-gray-900/90 to-gray-800/90 backdrop-blur-xl rounded-2xl border border-gray-700/50 shadow-2xl"></div>
      <div class="absolute inset-0 bg-gradient-to-br from-blue-500/5 to-purple-600/10 rounded-2xl"></div>
      
      <div class="relative z-10 p-6">
        <!-- Minimal Header -->
        <div class="mb-4">
          <p class="text-sm text-gray-400 font-medium"><%= gauge_subtitle(@category) %></p>
        </div>
        
        <!-- Professional 3D Gauge Container -->
        <div 
          id={@chart_id}
          class="w-full relative rounded-xl overflow-visible flex items-center justify-center"
          style="aspect-ratio: 1; max-width: 280px; margin: 0 auto; background: radial-gradient(circle at center, rgba(59, 130, 246, 0.1) 0%, rgba(0, 0, 0, 0.3) 70%);"
          phx-hook="ProfessionalGauge"
          data-category={@category}
          data-value={@gauge_data.smoothed_value}
          data-baseline-7d={@gauge_data.baseline_7d}
          data-baseline-30d={@gauge_data.baseline_30d}
          data-min-value={elem(@gauge_data.value_range, 0)}
          data-max-value={elem(@gauge_data.value_range, 1)}
          data-colors={Jason.encode!(gauge_colors(@gauge_data))}
          data-trend={@gauge_data.trend_direction}
          data-confidence={@gauge_data.confidence}
        >
          <!-- Loading Placeholder -->
          <div class="absolute inset-0 flex items-center justify-center">
            <div class="w-8 h-8 border-2 border-blue-500/20 border-t-blue-500 rounded-full animate-spin"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp gauge_title(:sentiment), do: "Global Sentiment"
  defp gauge_title(:financial), do: "Financial Pulse"
  defp gauge_title(:natural_events), do: "Natural Events"
  defp gauge_title(:social_trends), do: "Social Trends"

  defp gauge_subtitle(:sentiment), do: "Real-time global news sentiment"
  defp gauge_subtitle(:financial), do: "Market and economic indicators"
  defp gauge_subtitle(:natural_events), do: "Seismic and weather activity"
  defp gauge_subtitle(:social_trends), do: "Social media and cultural trends"

  defp format_gauge_value(value, :sentiment) do
    case value do
      v when v > 0.7 -> "#{round(v * 100)}% Positive"
      v when v > 0.3 -> "#{round(v * 100)}% Neutral"
      _ -> "#{round(value * 100)}% Negative"
    end
  end

  defp format_gauge_value(value, _category) do
    "#{Float.round(value, 1)}"
  end

  defp trend_indicator_color(:up), do: "bg-green-500"
  defp trend_indicator_color(:down), do: "bg-red-500"
  defp trend_indicator_color(:stable), do: "bg-yellow-500"

  defp trend_text(:up), do: "Rising"
  defp trend_text(:down), do: "Declining" 
  defp trend_text(:stable), do: "Stable"

  defp trend_strength_color(:up), do: "bg-green-500"
  defp trend_strength_color(:down), do: "bg-red-500"
  defp trend_strength_color(:stable), do: "bg-gray-500"

  defp modern_trend_gradient(:up), do: "bg-gradient-to-r from-green-400 to-emerald-500"
  defp modern_trend_gradient(:down), do: "bg-gradient-to-r from-red-400 to-rose-500"
  defp modern_trend_gradient(:stable), do: "bg-gradient-to-r from-yellow-400 to-amber-500"

  defp confidence_color(confidence) do
    cond do
      confidence > 0.8 -> "text-green-400"
      confidence > 0.6 -> "text-yellow-400"
      true -> "text-red-400"
    end
  end

  defp gauge_colors(gauge_data) do
    %{
      primary: gauge_data.color_scheme.accent,
      background: gauge_data.color_scheme.background,
      text: gauge_data.color_scheme.text
    }
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

  defp create_fallback_gauge_data(:sentiment) do
    %GlobalPulse.Services.GaugeDataManager.GaugeData{
      category: :sentiment,
      current_value: 0.5,
      smoothed_value: 0.5,
      baseline_7d: 0.5,
      baseline_30d: 0.5,
      trend_direction: :stable,
      trend_strength: 0.0,
      confidence: 0.3,
      last_updated: DateTime.utc_now(),
      value_range: {0.0, 1.0},
      color_scheme: %{
        negative: "#ef4444",
        neutral: "#f59e0b", 
        positive: "#10b981",
        background: "#1f2937",
        text: "#f3f4f6",
        accent: "#3b82f6"
      },
      history: []
    }
  end

  defp create_fallback_gauge_data(:financial) do
    %GlobalPulse.Services.GaugeDataManager.GaugeData{
      category: :financial,
      current_value: 50.0,
      smoothed_value: 50.0,
      baseline_7d: 50.0,
      baseline_30d: 50.0,
      trend_direction: :stable,
      trend_strength: 0.0,
      confidence: 0.3,
      last_updated: DateTime.utc_now(),
      value_range: {0.0, 100.0},
      color_scheme: %{
        low: "#ef4444",
        medium: "#f59e0b",
        high: "#10b981",
        background: "#1f2937",
        text: "#f3f4f6",
        accent: "#8b5cf6"
      },
      history: []
    }
  end

  defp create_fallback_gauge_data(:natural_events) do
    %GlobalPulse.Services.GaugeDataManager.GaugeData{
      category: :natural_events,
      current_value: 2.0,
      smoothed_value: 2.0,
      baseline_7d: 2.0,
      baseline_30d: 2.0,
      trend_direction: :stable,
      trend_strength: 0.0,
      confidence: 0.3,
      last_updated: DateTime.utc_now(),
      value_range: {0.0, 10.0},
      color_scheme: %{
        low: "#10b981",
        medium: "#f59e0b",
        high: "#ef4444",
        background: "#1f2937",
        text: "#f3f4f6",
        accent: "#f97316"
      },
      history: []
    }
  end

  defp create_fallback_gauge_data(:social_trends) do
    %GlobalPulse.Services.GaugeDataManager.GaugeData{
      category: :social_trends,
      current_value: 50.0,
      smoothed_value: 50.0,
      baseline_7d: 50.0,
      baseline_30d: 50.0,
      trend_direction: :stable,
      trend_strength: 0.0,
      confidence: 0.3,
      last_updated: DateTime.utc_now(),
      value_range: {0.0, 100.0},
      color_scheme: %{
        low: "#6b7280",
        medium: "#3b82f6",
        high: "#8b5cf6",
        background: "#1f2937",
        text: "#f3f4f6",
        accent: "#ec4899"
      },
      history: []
    }
  end

  defp create_fallback_gauge_data(category) do
    # Generic fallback
    %GlobalPulse.Services.GaugeDataManager.GaugeData{
      category: category,
      current_value: 0.5,
      smoothed_value: 0.5,
      baseline_7d: 0.5,
      baseline_30d: 0.5,
      trend_direction: :stable,
      trend_strength: 0.0,
      confidence: 0.1,
      last_updated: DateTime.utc_now(),
      value_range: {0.0, 1.0},
      color_scheme: %{
        background: "#1f2937",
        text: "#f3f4f6",
        accent: "#3b82f6"
      },
      history: []
    }
  end
end