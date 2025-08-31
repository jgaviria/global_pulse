defmodule GlobalPulseWeb.CoreComponents do
  use Phoenix.Component
  alias Phoenix.LiveView.JS
  
  attr :flash, :map, default: %{}, doc: "the map of flash messages"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling"
  
  def flash_group(assigns) do
    ~H"""
    <div class="fixed top-0 right-0 z-50 p-4">
      <.flash kind={:info} title="Success!" flash={@flash} />
      <.flash kind={:error} title="Error!" flash={@flash} />
    </div>
    """
  end
  
  def flash(assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      id={"flash-#{@kind}"}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide()}
      role="alert"
      class={[
        "fixed top-14 right-6 z-50 rounded-lg p-3 shadow-md shadow-gray-900 ring-1",
        @kind == :info && "bg-emerald-800 text-emerald-200 ring-emerald-700",
        @kind == :error && "bg-rose-800 text-rose-200 ring-rose-700"
      ]}
    >
      <p :if={@title} class="flex items-center gap-1.5 text-sm font-semibold leading-6">
        <.icon :if={@kind == :info} name="hero-check-circle-mini" class="h-4 w-4" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="h-4 w-4" />
        <%= @title %>
      </p>
      <p class="mt-2 text-sm leading-5"><%= msg %></p>
      <button type="button" class="group absolute top-1 right-1 p-2" aria-label="close">
        <.icon name="hero-x-mark-solid" class="h-5 w-5 opacity-60 group-hover:opacity-100" />
      </button>
    </div>
    """
  end
  
  def hide(js \\ %JS{}) do
    js
    |> JS.hide(to: "#flash", transition: "fade-out")
  end
  
  attr :name, :string, required: true
  attr :class, :string, default: nil
  
  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end
  
  def threat_level_class(level) do
    case level do
      :low -> "bg-green-500/20 text-green-400 border border-green-500/50"
      :moderate -> "bg-yellow-500/20 text-yellow-400 border border-yellow-500/50"
      :high -> "bg-orange-500/20 text-orange-400 border border-orange-500/50"
      :critical -> "bg-red-500/20 text-red-400 border border-red-500/50 animate-pulse"
      _ -> "bg-gray-500/20 text-gray-400 border border-gray-500/50"
    end
  end
  
  def market_trend_class(trend) do
    case trend do
      :bullish -> "bg-green-500/20 text-green-400"
      :bearish -> "bg-red-500/20 text-red-400"
      _ -> "bg-gray-500/20 text-gray-400"
    end
  end
  
  def sentiment_class(sentiment) when is_number(sentiment) do
    cond do
      sentiment > 0.5 -> "bg-green-500/20 text-green-400"
      sentiment < -0.5 -> "bg-red-500/20 text-red-400"
      true -> "bg-gray-500/20 text-gray-400"
    end
  end
  def sentiment_class(_), do: "bg-gray-500/20 text-gray-400"
  
  def sentiment_label(sentiment) when is_number(sentiment) do
    cond do
      sentiment > 0.5 -> "POSITIVE"
      sentiment < -0.5 -> "NEGATIVE"
      true -> "NEUTRAL"
    end
  end
  def sentiment_label(_), do: "UNKNOWN"
  
  def sentiment_color(sentiment) when is_number(sentiment) do
    cond do
      sentiment > 0 -> "text-green-400"
      sentiment < 0 -> "text-red-400"
      true -> "text-gray-400"
    end
  end
  def sentiment_color(_), do: "text-gray-400"
  
  def vix_color(vix) when is_number(vix) do
    cond do
      vix < 20 -> "text-green-400"
      vix < 30 -> "text-yellow-400"
      true -> "text-red-400"
    end
  end
  def vix_color(_), do: "text-gray-400"
  
  def space_weather_class(severity) do
    case severity do
      "Extreme" -> "bg-red-500/20 text-red-400"
      "Severe" -> "bg-orange-500/20 text-orange-400"
      "Strong" -> "bg-yellow-500/20 text-yellow-400"
      "Moderate" -> "bg-blue-500/20 text-blue-400"
      _ -> "bg-green-500/20 text-green-400"
    end
  end
  
  def earthquake_color(count) when is_number(count) do
    cond do
      count > 10 -> "text-red-400"
      count > 5 -> "text-yellow-400"
      true -> "text-green-400"
    end
  end
  def earthquake_color(_), do: "text-gray-400"
  
  def anomaly_severity_color(severity) do
    case severity do
      :critical -> "bg-red-500 animate-pulse"
      :high -> "bg-orange-500"
      :medium -> "bg-yellow-500"
      :low -> "bg-blue-500"
      _ -> "bg-gray-500"
    end
  end
  
  def format_anomaly_type(type) do
    type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
  
  def format_anomaly_details(anomaly) do
    case anomaly[:type] do
      :price_anomaly ->
        "#{anomaly[:symbol]} - #{abs(Float.round(anomaly[:change] * 100, 2))}% change"
      :volume_spike ->
        "#{anomaly[:symbol]} - Volume: #{format_large_number(anomaly[:volume])}"
      :sentiment_shift ->
        "Market sentiment: #{anomaly[:direction]}"
      :earthquake_swarm ->
        "#{anomaly[:count]} events in #{anomaly[:region]}"
      _ ->
        inspect(anomaly[:details] || anomaly)
    end
  end
  
  def format_relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)
    
    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end
  
  def format_large_number(num) when is_number(num) do
    cond do
      num >= 1_000_000_000 -> "#{Float.round(num / 1_000_000_000, 2)}B"
      num >= 1_000_000 -> "#{Float.round(num / 1_000_000, 2)}M"
      num >= 1_000 -> "#{Float.round(num / 1_000, 2)}K"
      true -> "#{num}"
    end
  end
  def format_large_number(_), do: "N/A"
  
  def format_number(num) when is_number(num) do
    if num >= 1000 do
      format_large_number(num)
    else
      Float.round(num, 2)
    end
  end
  def format_number(_), do: "N/A"
  
  def fear_greed_badge(index) when is_number(index) do
    cond do
      index < 20 -> "bg-red-500/20 text-red-400"
      index < 40 -> "bg-orange-500/20 text-orange-400"
      index < 60 -> "bg-yellow-500/20 text-yellow-400"
      index < 80 -> "bg-green-500/20 text-green-400"
      true -> "bg-emerald-500/20 text-emerald-400"
    end
  end
  def fear_greed_badge(_), do: "bg-gray-500/20 text-gray-400"
  
  def fear_greed_label(index) when is_number(index) do
    cond do
      index < 20 -> "Extreme Fear"
      index < 40 -> "Fear"
      index < 60 -> "Neutral"
      index < 80 -> "Greed"
      true -> "Extreme Greed"
    end
  end
  def fear_greed_label(_), do: "Unknown"
  
  def fear_greed_color(index) when is_number(index) do
    cond do
      index < 20 -> "bg-red-500"
      index < 40 -> "bg-orange-500"
      index < 60 -> "bg-yellow-500"
      index < 80 -> "bg-green-500"
      true -> "bg-emerald-500"
    end
  end
  def fear_greed_color(_), do: "bg-gray-500"
  
  def volatility_badge(vol) when is_number(vol) do
    cond do
      vol < 15 -> "bg-green-500/20 text-green-400"
      vol < 25 -> "bg-yellow-500/20 text-yellow-400"
      vol < 35 -> "bg-orange-500/20 text-orange-400"
      true -> "bg-red-500/20 text-red-400"
    end
  end
  def volatility_badge(_), do: "bg-gray-500/20 text-gray-400"
  
  def volatility_label(vol) when is_number(vol) do
    cond do
      vol < 15 -> "Low"
      vol < 25 -> "Normal"
      vol < 35 -> "High"
      true -> "Extreme"
    end
  end
  def volatility_label(_), do: "Unknown"
  
  def commodity_color(name) do
    case String.downcase(name) do
      "gold" -> "bg-yellow-500/20"
      "silver" -> "bg-gray-400/20"
      "oil" -> "bg-gray-900"
      "gas" -> "bg-blue-500/20"
      _ -> "bg-purple-500/20"
    end
  end
  
  def correlation_color(corr) when is_number(corr) do
    cond do
      corr > 0.7 -> "text-green-400"
      corr > 0.3 -> "text-green-300"
      corr > -0.3 -> "text-gray-400"
      corr > -0.7 -> "text-red-300"
      true -> "text-red-400"
    end
  end
  def correlation_color(_), do: "text-gray-400"
  
  def correlation_bar_color(corr) when is_number(corr) do
    if corr > 0, do: "bg-green-500", else: "bg-red-500"
  end
  def correlation_bar_color(_), do: "bg-gray-500"
  
  def event_impact_color(impact) when is_number(impact) do
    cond do
      impact > 0.8 -> "bg-red-500"
      impact > 0.6 -> "bg-orange-500"
      impact > 0.4 -> "bg-yellow-500"
      true -> "bg-blue-500"
    end
  end
  def event_impact_color(_), do: "bg-gray-500"
  
  def impact_badge(impact) when is_number(impact) do
    cond do
      impact > 0.8 -> "bg-red-500/20 text-red-400"
      impact > 0.6 -> "bg-orange-500/20 text-orange-400"
      impact > 0.4 -> "bg-yellow-500/20 text-yellow-400"
      true -> "bg-blue-500/20 text-blue-400"
    end
  end
  def impact_badge(_), do: "bg-gray-500/20 text-gray-400"

  def magnitude_color(magnitude) when is_number(magnitude) do
    cond do
      magnitude >= 7.0 -> "bg-red-500"
      magnitude >= 6.0 -> "bg-orange-500"
      magnitude >= 5.0 -> "bg-yellow-500"
      magnitude >= 4.0 -> "bg-blue-500"
      true -> "bg-gray-500"
    end
  end
  def magnitude_color(_), do: "bg-gray-500"

  def category_badge(category) when is_number(category) do
    case category do
      5 -> "bg-red-600 text-white"
      4 -> "bg-red-500 text-white"
      3 -> "bg-orange-500 text-white"
      2 -> "bg-yellow-500 text-white"
      1 -> "bg-blue-500 text-white"
      _ -> "bg-gray-500 text-white"
    end
  end
  def category_badge(_), do: "bg-gray-500 text-white"

  def threat_level_badge(level) do
    case String.downcase(to_string(level)) do
      "critical" -> "bg-red-500/20 text-red-400"
      "high" -> "bg-orange-500/20 text-orange-400"
      "medium" -> "bg-yellow-500/20 text-yellow-400"
      "low" -> "bg-green-500/20 text-green-400"
      _ -> "bg-gray-500/20 text-gray-400"
    end
  end

  def anomaly_severity_badge(severity) do
    case severity do
      :critical -> "bg-red-500/20 text-red-400"
      :high -> "bg-orange-500/20 text-orange-400"
      :medium -> "bg-yellow-500/20 text-yellow-400"
      :low -> "bg-blue-500/20 text-blue-400"
      _ -> "bg-gray-500/20 text-gray-400"
    end
  end

  # Phoenix.Component already provides the link function
end