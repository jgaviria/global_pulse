defmodule GlobalPulse.Services.GaugeDataManager do
  @moduledoc """
  Manages historical baseline data and real-time updates for all gauge types.
  
  Provides:
  - Historical baseline calculation (7-day, 30-day averages)
  - Real-time value updates with smoothing
  - Trend detection and confidence scoring
  - Multi-category support (sentiment, financial, natural events, social trends)
  """
  use GenServer
  require Logger
  
  @update_interval 60_000  # 1 minute
  @max_history_days 30
  @smoothing_factor 0.3    # For exponential smoothing
  
  defmodule GaugeData do
    defstruct [
      :category,           # :sentiment, :financial, :natural_events, :social_trends
      :current_value,      # Current raw value
      :smoothed_value,     # Exponentially smoothed value
      :baseline_7d,        # 7-day rolling average
      :baseline_30d,       # 30-day rolling average
      :trend_direction,    # :up, :down, :stable
      :trend_strength,     # 0.0 to 1.0
      :confidence,         # 0.0 to 1.0
      :last_updated,       # DateTime
      :value_range,        # {min, max} for normalization
      :color_scheme,       # Color configuration
      :history             # List of {timestamp, value} tuples
    ]
  end
  
  # ============================================================================
  # PUBLIC API
  # ============================================================================
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get_gauge_data(category) do
    GenServer.call(__MODULE__, {:get_data, category})
  end
  
  def update_value(category, value, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:update_value, category, value, metadata})
  end
  
  def get_all_gauges do
    GenServer.call(__MODULE__, :get_all_gauges)
  end
  
  # ============================================================================
  # GENSERVER CALLBACKS
  # ============================================================================
  
  def init(_opts) do
    # Initialize gauge data for all categories
    initial_state = %{
      sentiment: initialize_gauge_data(:sentiment),
      financial: initialize_gauge_data(:financial),
      natural_events: initialize_gauge_data(:natural_events),
      social_trends: initialize_gauge_data(:social_trends)
    }
    
    # Schedule periodic baseline updates
    Process.send_after(self(), :update_baselines, @update_interval)
    
    Logger.info("🎯 GaugeDataManager: Initialized with #{Map.keys(initial_state) |> length()} gauge categories")
    {:ok, initial_state}
  end
  
  def handle_call({:get_data, category}, _from, state) do
    gauge_data = Map.get(state, category, initialize_gauge_data(category))
    {:reply, gauge_data, state}
  end
  
  def handle_call(:get_all_gauges, _from, state) do
    {:reply, state, state}
  end
  
  def handle_cast({:update_value, category, value, metadata}, state) do
    case Map.get(state, category) do
      nil -> 
        Logger.warning("🎯 Unknown gauge category: #{category}")
        {:noreply, state}
      
      current_data ->
        updated_data = update_gauge_data(current_data, value, metadata)
        new_state = Map.put(state, category, updated_data)
        
        # Broadcast update to subscribers
        broadcast_gauge_update(category, updated_data)
        
        {:noreply, new_state}
    end
  end
  
  def handle_info(:update_baselines, state) do
    # Update historical baselines for all categories
    updated_state = state
    |> Enum.map(fn {category, data} ->
      {category, recalculate_baselines(data)}
    end)
    |> Map.new()
    
    # Schedule next update
    Process.send_after(self(), :update_baselines, @update_interval)
    
    {:noreply, updated_state}
  end
  
  # ============================================================================
  # GAUGE DATA INITIALIZATION
  # ============================================================================
  
  defp initialize_gauge_data(:sentiment) do
    %GaugeData{
      category: :sentiment,
      current_value: 0.0,
      smoothed_value: 0.0,
      baseline_7d: 0.0,
      baseline_30d: 0.0,
      trend_direction: :stable,
      trend_strength: 0.0,
      confidence: 0.5,
      last_updated: DateTime.utc_now(),
      value_range: {-1.0, 1.0},
      color_scheme: sentiment_color_scheme(),
      history: []
    }
  end
  
  defp initialize_gauge_data(:financial) do
    %GaugeData{
      category: :financial,
      current_value: 50.0,
      smoothed_value: 50.0,
      baseline_7d: 50.0,
      baseline_30d: 50.0,
      trend_direction: :stable,
      trend_strength: 0.0,
      confidence: 0.5,
      last_updated: DateTime.utc_now(),
      value_range: {0.0, 100.0},
      color_scheme: financial_color_scheme(),
      history: []
    }
  end
  
  defp initialize_gauge_data(:natural_events) do
    %GaugeData{
      category: :natural_events,
      current_value: 2.0,
      smoothed_value: 2.0,
      baseline_7d: 2.0,
      baseline_30d: 2.0,
      trend_direction: :stable,
      trend_strength: 0.0,
      confidence: 0.5,
      last_updated: DateTime.utc_now(),
      value_range: {0.0, 10.0},
      color_scheme: natural_events_color_scheme(),
      history: []
    }
  end
  
  defp initialize_gauge_data(:social_trends) do
    %GaugeData{
      category: :social_trends,
      current_value: 50.0,
      smoothed_value: 50.0,
      baseline_7d: 50.0,
      baseline_30d: 50.0,
      trend_direction: :stable,
      trend_strength: 0.0,
      confidence: 0.5,
      last_updated: DateTime.utc_now(),
      value_range: {0.0, 100.0},
      color_scheme: social_trends_color_scheme(),
      history: []
    }
  end
  
  # ============================================================================
  # COLOR SCHEMES
  # ============================================================================
  
  defp sentiment_color_scheme do
    %{
      negative: "#ef4444",    # Red
      neutral: "#f59e0b",     # Amber  
      positive: "#10b981",    # Emerald
      background: "#1f2937",  # Gray-800
      text: "#f3f4f6",       # Gray-100
      accent: "#3b82f6"      # Blue
    }
  end
  
  defp financial_color_scheme do
    %{
      low: "#ef4444",        # Red
      medium: "#f59e0b",     # Amber
      high: "#10b981",       # Emerald
      background: "#1f2937", 
      text: "#f3f4f6",
      accent: "#8b5cf6"      # Purple
    }
  end
  
  defp natural_events_color_scheme do
    %{
      low: "#10b981",        # Green (good - low severity)
      medium: "#f59e0b",     # Amber
      high: "#ef4444",       # Red (bad - high severity)
      background: "#1f2937",
      text: "#f3f4f6", 
      accent: "#f97316"      # Orange
    }
  end
  
  defp social_trends_color_scheme do
    %{
      low: "#6b7280",        # Gray
      medium: "#3b82f6",     # Blue
      high: "#8b5cf6",       # Purple
      background: "#1f2937",
      text: "#f3f4f6",
      accent: "#ec4899"      # Pink
    }
  end
  
  # ============================================================================
  # GAUGE DATA UPDATES
  # ============================================================================
  
  defp update_gauge_data(current_data, new_value, metadata) do
    now = DateTime.utc_now()
    
    # Normalize value to range
    normalized_value = normalize_value(new_value, current_data.value_range)
    
    # Apply exponential smoothing
    smoothed_value = apply_smoothing(current_data.smoothed_value, normalized_value, @smoothing_factor)
    
    # Update history (keep last 30 days)
    updated_history = update_history(current_data.history, {now, normalized_value})
    
    # Calculate baselines
    baseline_7d = calculate_baseline(updated_history, 7)
    baseline_30d = calculate_baseline(updated_history, 30)
    
    # Detect trend
    {trend_direction, trend_strength} = detect_trend(updated_history)
    
    # Calculate confidence based on data points and recency
    confidence = calculate_confidence(updated_history, metadata)
    
    %{current_data |
      current_value: normalized_value,
      smoothed_value: smoothed_value,
      baseline_7d: baseline_7d,
      baseline_30d: baseline_30d,
      trend_direction: trend_direction,
      trend_strength: trend_strength,
      confidence: confidence,
      last_updated: now,
      history: updated_history
    }
  end
  
  defp normalize_value(value, {min_val, max_val}) do
    cond do
      value < min_val -> min_val
      value > max_val -> max_val
      true -> value
    end
  end
  
  defp apply_smoothing(previous_smoothed, new_value, alpha) do
    alpha * new_value + (1 - alpha) * previous_smoothed
  end
  
  defp update_history(history, {timestamp, value}) do
    cutoff_time = DateTime.add(timestamp, -@max_history_days, :day)
    
    # Add new point and remove old ones
    [{timestamp, value} | history]
    |> Enum.filter(fn {ts, _} -> 
      DateTime.compare(ts, cutoff_time) == :gt
    end)
    |> Enum.take(1000)  # Limit to 1000 points max
  end
  
  defp calculate_baseline(history, days) do
    if length(history) < 2 do
      0.0
    else
      cutoff_time = DateTime.add(DateTime.utc_now(), -days, :day)
      
      recent_values = history
      |> Enum.filter(fn {ts, _} -> 
        DateTime.compare(ts, cutoff_time) == :gt
      end)
      |> Enum.map(fn {_, value} -> value end)
      
      case recent_values do
        [] -> 0.0
        values -> Enum.sum(values) / length(values)
      end
    end
  end
  
  defp detect_trend(history) do
    if length(history) < 10 do
      {:stable, 0.0}
    else
      # Take recent 10 points and calculate slope
      recent_points = Enum.take(history, 10)
      |> Enum.with_index()
      |> Enum.map(fn {{_ts, value}, index} -> {index, value} end)
      
      slope = calculate_slope(recent_points)
      
      cond do
        slope > 0.01 -> {:up, min(slope * 10, 1.0)}
        slope < -0.01 -> {:down, min(abs(slope) * 10, 1.0)}
        true -> {:stable, 0.0}
      end
    end
  end
  
  defp calculate_slope(points) do
    n = length(points)
    if n < 2 do
      0.0
    else
      {sum_x, sum_y, sum_xy, sum_x2} = points
      |> Enum.reduce({0, 0, 0, 0}, fn {x, y}, {sx, sy, sxy, sx2} ->
        {sx + x, sy + y, sxy + x * y, sx2 + x * x}
      end)
      
      denominator = n * sum_x2 - sum_x * sum_x
      if denominator == 0 do
        0.0
      else
        (n * sum_xy - sum_x * sum_y) / denominator
      end
    end
  end
  
  defp calculate_confidence(history, metadata) do
    base_confidence = 0.5
    
    # More data points = higher confidence
    data_confidence = min(length(history) / 100.0, 1.0) * 0.3
    
    # Recent updates = higher confidence
    recency_confidence = case history do
      [{last_update, _} | _] ->
        hours_ago = DateTime.diff(DateTime.utc_now(), last_update, :second) / 3600.0
        max(0.0, (24.0 - hours_ago) / 24.0) * 0.2
      _ -> 0.0
    end
    
    # Metadata-based confidence (if provided)
    metadata_confidence = Map.get(metadata, :confidence, 0.0) * 0.2
    
    min(1.0, base_confidence + data_confidence + recency_confidence + metadata_confidence)
  end
  
  defp recalculate_baselines(data) do
    baseline_7d = calculate_baseline(data.history, 7)
    baseline_30d = calculate_baseline(data.history, 30)
    
    %{data | baseline_7d: baseline_7d, baseline_30d: baseline_30d}
  end
  
  # ============================================================================
  # PUBSUB BROADCASTING
  # ============================================================================
  
  defp broadcast_gauge_update(category, gauge_data) do
    Phoenix.PubSub.broadcast(
      GlobalPulse.PubSub,
      "gauge_updates",
      {:gauge_update, category, gauge_data}
    )
  end
end