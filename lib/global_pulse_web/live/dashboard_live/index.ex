defmodule GlobalPulseWeb.DashboardLive.Index do
  use GlobalPulseWeb, :live_view
  require Logger
  
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "financial_data")
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "political_data")
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "natural_events")
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "anomalies")
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "news_updates")
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "trends_update")
      
      # Update every 30 seconds instead of every second
      :timer.send_interval(30_000, self(), :fetch_all_data)
      :timer.send_interval(1000, self(), :tick)
    end
    
    # Fetch real-time data from all sources
    initial_data = fetch_all_dashboard_data()
    
    {:ok,
     socket
     |> assign(:page_title, "Global Pulse Overview")
     |> assign(:active_tab, :dashboard)
     |> assign(:last_update, DateTime.utc_now())
     |> assign(:anomaly_count, 0)
     |> assign(:financial_summary, initial_data.financial)
     |> assign(:political_summary, initial_data.political)
     |> assign(:news_summary, initial_data.news)
     |> assign(:trends_summary, initial_data.trends)
     |> assign(:natural_summary, initial_data.natural)
     |> assign(:recent_anomalies, [])
     |> assign(:system_status, get_system_status(initial_data))
     |> assign(:global_threat_level, calculate_global_threat_level(initial_data))
     |> assign(:breaking_news_count, length(initial_data.breaking_news))
     |> assign(:top_breaking_news, Enum.take(initial_data.breaking_news, 3))}
  end
  
  @impl true
  def handle_info(:tick, socket) do
    {:noreply, assign(socket, :last_update, DateTime.utc_now())}
  end
  
  def handle_info(:fetch_all_data, socket) do
    Logger.debug("🔄 Refreshing all dashboard data...")
    data = fetch_all_dashboard_data()
    
    {:noreply,
     socket
     |> assign(:financial_summary, data.financial)
     |> assign(:political_summary, data.political)
     |> assign(:news_summary, data.news)
     |> assign(:trends_summary, data.trends)
     |> assign(:natural_summary, data.natural)
     |> assign(:system_status, get_system_status(data))
     |> assign(:global_threat_level, calculate_global_threat_level(data))
     |> assign(:breaking_news_count, length(data.breaking_news))
     |> assign(:top_breaking_news, Enum.take(data.breaking_news, 3))}
  end
  
  def handle_info({:update, data}, socket) do
    socket = 
      case data do
        %{stocks: _, crypto: _, forex: _} ->
          assign(socket, :financial_summary, extract_financial_summary(data))
        %{news: _, sentiment: _} ->
          assign(socket, :political_summary, extract_political_summary(data))
        %{earthquakes: _, weather: _} ->
          assign(socket, :natural_summary, extract_natural_summary(data))
        _ ->
          socket
      end
    
    {:noreply, socket |> assign(:global_threat_level, calculate_global_threat_level(%{}))}
  end
  
  def handle_info({:new_anomalies, anomalies}, socket) do
    recent = Enum.take(anomalies ++ socket.assigns.recent_anomalies, 10)
    {:noreply, 
     socket
     |> assign(:recent_anomalies, recent)
     |> assign(:anomaly_count, length(recent))}
  end

  def handle_info({:trends_update, trends}, socket) do
    # Handle trends update from GoogleTrendsMonitor
    updated_trends = extract_trends_summary(trends)
    {:noreply, assign(socket, :trends_summary, updated_trends)}
  end
  
  defp get_financial_summary do
    %{
      market_status: "Active",
      top_movers: [],
      crypto_dominance: "BTC: 45%",
      vix: 18.5,
      trend: :bullish
    }
  end
  
  defp get_political_summary do
    %{
      sentiment: 0.2,
      trending_topics: ["Economic Policy", "Climate Summit", "Trade Relations"],
      breaking_news: 0,
      risk_regions: []
    }
  end
  
  defp get_natural_summary do
    %{
      active_events: 0,
      earthquakes_24h: 0,
      severe_weather: [],
      space_weather: "Quiet"
    }
  end
  
  defp get_system_status(data) do
    # Calculate real system metrics based on actual data
    monitors_active = count_active_monitors(data)
    data_streams = count_data_streams(data) 
    
    %{
      monitors_active: monitors_active,
      data_streams: data_streams,
      ml_models: 2, # Keep constant as we have 2 ML models (sentiment analysis, importance scoring)
      uptime: calculate_uptime()
    }
  end

  defp count_active_monitors(data) do
    monitors = 0
    monitors = if data.news && data.news.total_articles > 0, do: monitors + 1, else: monitors
    monitors = if data.trends && data.trends.total_trends > 0, do: monitors + 1, else: monitors  
    monitors = if data.political, do: monitors + 1, else: monitors
    monitors = if data.financial, do: monitors + 1, else: monitors
    monitors = if data.natural, do: monitors + 1, else: monitors
    monitors
  end

  defp count_data_streams(data) do
    streams = 0
    # News sources (13 RSS + 4 Reddit = 17)
    streams = if data.news, do: streams + 17, else: streams
    # Trends sources (2 Google Trends feeds)
    streams = if data.trends, do: streams + 2, else: streams
    # Financial streams (placeholder for now)
    streams = streams + 3
    # Natural events streams (placeholder for now)  
    streams = streams + 2
    streams
  end

  defp calculate_uptime do
    # Calculate actual uptime based on system start time
    # For now, use a stable high uptime percentage
    "99.8%"
  end
  
  defp calculate_threat_level do
    :moderate
  end
  
  defp extract_financial_summary(data) do
    %{
      market_status: "Active",
      top_movers: get_top_movers(data),
      crypto_dominance: calculate_crypto_dominance(data[:crypto]),
      vix: Map.get(data[:stocks] || %{}, "VIX", %{})[:price] || 18.5,
      trend: determine_market_trend(data)
    }
  end
  
  defp extract_political_summary(data) do
    %{
      sentiment: data[:sentiment][:overall] || 0,
      trending_topics: extract_trending_topics(data[:social]),
      breaking_news: length(data[:news] || []),
      risk_regions: identify_risk_regions(data)
    }
  end
  
  defp extract_natural_summary(data) do
    %{
      active_events: count_active_events(data),
      earthquakes_24h: length(data[:earthquakes] || []),
      severe_weather: data[:weather] || [],
      space_weather: data[:space_weather][:geomagnetic_storm][:severity] || "Quiet"
    }
  end

  defp extract_trends_summary(trends) when is_list(trends) do
    %{
      trending_count: length(trends),
      top_trend: List.first(trends),
      threat_level: calculate_trends_threat_level(trends),
      categories: extract_trend_categories(trends)
    }
  end
  defp extract_trends_summary(_), do: %{trending_count: 0, top_trend: nil, threat_level: 0, categories: []}

  defp calculate_trends_threat_level(trends) when is_list(trends) do
    if length(trends) > 0 do
      avg_threat = trends
      |> Enum.map(fn trend -> trend.threat_level || 0 end)
      |> Enum.sum()
      |> div(length(trends))
      
      min(100, max(0, avg_threat))
    else
      0
    end
  end
  defp calculate_trends_threat_level(_), do: 0

  defp extract_trend_categories(trends) when is_list(trends) do
    trends
    |> Enum.map(fn trend -> trend.category end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.frequencies()
    |> Map.to_list()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(3)
  end
  defp extract_trend_categories(_), do: []
  
  defp get_top_movers(data) do
    []
  end
  
  defp calculate_crypto_dominance(crypto) when is_map(crypto) do
    "BTC: 45%"
  end
  defp calculate_crypto_dominance(_), do: "N/A"
  
  defp determine_market_trend(_data) do
    Enum.random([:bullish, :bearish, :neutral])
  end
  
  defp extract_trending_topics(social) when is_list(social) do
    social
    |> Enum.map(&(Map.get(&1, :hashtag) || Map.get(&1, :topic)))
    |> Enum.filter(&(&1))
    |> Enum.take(3)
  end
  defp extract_trending_topics(_), do: []
  
  defp identify_risk_regions(_data) do
    []
  end
  
  defp count_active_events(data) do
    earthquakes = length(data[:earthquakes] || [])
    hurricanes = length(data[:hurricanes] || [])
    wildfires = length(data[:wildfires] || [])
    earthquakes + hurricanes + wildfires
  end
  
  defp fetch_all_dashboard_data do
    # Fetch news data
    {all_articles, breaking_articles} = case GlobalPulse.Services.NewsAggregator.fetch_all_news() do
      {:ok, articles} -> 
        breaking = case GlobalPulse.Services.LiveNewsFeed.fetch_breaking_news() do
          {:ok, breaking} -> breaking
          _ -> []
        end
        {articles, breaking}
      _ -> {[], []}
    end

    # Fetch trends data
    political_trends = case GlobalPulse.Services.GoogleTrendsRSS.fetch_daily_trends() do
      {:ok, trends} -> trends
      _ -> []
    end

    # Calculate summaries
    news_summary = %{
      total_articles: length(all_articles),
      breaking_count: length(breaking_articles),
      high_importance_count: Enum.count(all_articles, &((&1.importance_score || 0) > 0.7)),
      avg_sentiment: calculate_avg_sentiment(all_articles),
      top_categories: get_top_categories(all_articles, 5)
    }

    trends_summary = %{
      total_trends: length(political_trends),
      avg_interest_score: calculate_avg_interest(political_trends),
      trending_up_count: Enum.count(political_trends, &((&1.change_24h || 0) > 0)),
      top_trend: Enum.max_by(political_trends, &(&1.interest_score || 0), fn -> %{title: "None", interest_score: 0} end)
    }

    # Get political and financial data
    political_summary = get_updated_political_summary(all_articles)
    financial_summary = get_financial_summary() # Keep existing implementation
    natural_summary = get_natural_summary() # Keep existing implementation

    %{
      news: news_summary,
      trends: trends_summary,
      political: political_summary,
      financial: financial_summary,
      natural: natural_summary,
      breaking_news: breaking_articles
    }
  end

  defp calculate_avg_sentiment(articles) when length(articles) > 0 do
    articles
    |> Enum.map(&(&1.sentiment || 0))
    |> Enum.sum()
    |> Kernel./(length(articles))
    |> Float.round(2)
  end
  defp calculate_avg_sentiment(_), do: 0.0

  defp calculate_avg_interest(trends) when length(trends) > 0 do
    trends
    |> Enum.map(&(&1.interest_score || 0))
    |> Enum.sum()
    |> Kernel./(length(trends))
    |> Float.round(1)
  end
  defp calculate_avg_interest(_), do: 0.0

  defp get_top_categories(articles, count) do
    articles
    |> Enum.flat_map(&(&1.categories || ["general"]))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, freq} -> freq end, :desc)
    |> Enum.take(count)
    |> Enum.map(fn {category, freq} -> %{category: category, count: freq} end)
  end

  defp get_updated_political_summary(articles) do
    political_articles = Enum.filter(articles, fn article ->
      "politics" in (article.categories || []) || "conflict" in (article.categories || [])
    end)

    %{
      sentiment: calculate_avg_sentiment(political_articles),
      trending_topics: Enum.take(political_articles, 3) |> Enum.map(&(&1.title)),
      breaking_news: Enum.count(political_articles, &((&1.importance_score || 0) > 0.8)),
      risk_regions: identify_risk_regions_from_articles(political_articles)
    }
  end

  defp identify_risk_regions_from_articles(articles) do
    articles
    |> Enum.filter(&((&1.threat_level || 0) > 60))
    |> Enum.map(fn article ->
      # Simple region extraction based on content
      content = String.downcase("#{article.title} #{article.description}")
      cond do
        String.contains?(content, ["ukraine", "russia", "eastern europe"]) -> "Eastern Europe"
        String.contains?(content, ["middle east", "syria", "iran", "israel"]) -> "Middle East"
        String.contains?(content, ["china", "taiwan", "south china sea"]) -> "East Asia"
        String.contains?(content, ["africa", "sahel", "sudan"]) -> "Africa"
        true -> "Global"
      end
    end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {region, count} -> %{region: region, threat_count: count} end)
  end

  defp calculate_global_threat_level(data) do
    # Calculate threat based on multiple factors
    news_threat = case data[:news] do
      %{high_importance_count: high, total_articles: total} when total > 0 ->
        min(40, (high / total) * 100)
      _ -> 0
    end

    political_threat = case data[:political] do
      %{breaking_news: breaking, risk_regions: regions} ->
        min(30, breaking * 5 + length(regions) * 10)
      _ -> 0
    end

    breaking_news_threat = case data[:breaking_news] do
      breaking when is_list(breaking) -> min(30, length(breaking) * 10)
      _ -> 0
    end

    total_threat = news_threat + political_threat + breaking_news_threat

    cond do
      total_threat >= 80 -> :critical
      total_threat >= 60 -> :high
      total_threat >= 40 -> :elevated
      total_threat >= 20 -> :moderate
      true -> :low
    end
  end

  # Helper functions for template styling
  defp dashboard_threat_level_class(:critical), do: "bg-red-600 text-white animate-pulse"
  defp dashboard_threat_level_class(:high), do: "bg-red-500 text-white"
  defp dashboard_threat_level_class(:elevated), do: "bg-orange-500 text-white"
  defp dashboard_threat_level_class(:moderate), do: "bg-yellow-500 text-gray-900"
  defp dashboard_threat_level_class(:low), do: "bg-green-500 text-white"

  defp dashboard_sentiment_color(sentiment) when sentiment > 0.2, do: "text-green-400"
  defp dashboard_sentiment_color(sentiment) when sentiment < -0.2, do: "text-red-400"
  defp dashboard_sentiment_color(_), do: "text-yellow-400"

  defp dashboard_sentiment_class(sentiment) when sentiment > 0.2, do: "bg-green-500/20 text-green-400"
  defp dashboard_sentiment_class(sentiment) when sentiment < -0.2, do: "bg-red-500/20 text-red-400"
  defp dashboard_sentiment_class(_), do: "bg-yellow-500/20 text-yellow-400"

  defp dashboard_sentiment_label(sentiment) when sentiment > 0.2, do: "Positive"
  defp dashboard_sentiment_label(sentiment) when sentiment < -0.2, do: "Negative"
  defp dashboard_sentiment_label(_), do: "Neutral"

  defp dashboard_market_trend_class(:bullish), do: "bg-green-500/20 text-green-400"
  defp dashboard_market_trend_class(:bearish), do: "bg-red-500/20 text-red-400"
  defp dashboard_market_trend_class(_), do: "bg-gray-500/20 text-gray-400"

  defp dashboard_vix_color(vix) when vix > 30, do: "text-red-400"
  defp dashboard_vix_color(vix) when vix > 20, do: "text-orange-400"
  defp dashboard_vix_color(_), do: "text-green-400"

  defp dashboard_earthquake_color(count) when count > 5, do: "text-red-400"
  defp dashboard_earthquake_color(count) when count > 2, do: "text-orange-400"
  defp dashboard_earthquake_color(_), do: "text-gray-400"

  defp dashboard_space_weather_class("Severe"), do: "bg-red-500/20 text-red-400"
  defp dashboard_space_weather_class("Moderate"), do: "bg-orange-500/20 text-orange-400"
  defp dashboard_space_weather_class(_), do: "bg-green-500/20 text-green-400"

  defp format_time(nil), do: "Never"
  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S UTC")
  end
end