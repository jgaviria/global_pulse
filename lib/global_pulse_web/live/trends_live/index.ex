defmodule GlobalPulseWeb.TrendsLive.Index do
  use GlobalPulseWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "trends_update")
      
      # Refresh trends data every 5 minutes (Google Trends data doesn't change frequently)
      :timer.send_interval(300_000, self(), :fetch_trends)
    end

    # Get initial trends data
    trends_data = fetch_initial_trends_data()

    {:ok,
     socket
     |> assign(:page_title, "Global Pulse Trends")
     |> assign(:active_tab, :trends)
     |> assign(:last_update, DateTime.utc_now())
     |> assign(:political_trends, trends_data.political)
     |> assign(:global_trends, trends_data.global)
     |> assign(:regional_trends, trends_data.regional)
     |> assign(:trending_keywords, trends_data.trending_keywords)
     |> assign(:trends_summary, calculate_trends_summary(trends_data))
     |> assign(:selected_region, "global")
     |> assign(:loading, false)
     |> assign(:anomaly_count, 0)
     |> assign(:breaking_news_count, 0)}
  end

  @impl true
  def handle_info(:fetch_trends, socket) do
    Logger.debug("🔄 Refreshing trends data...")
    trends_data = fetch_initial_trends_data()
    
    {:noreply,
     socket
     |> assign(:political_trends, trends_data.political)
     |> assign(:global_trends, trends_data.global)
     |> assign(:regional_trends, trends_data.regional)
     |> assign(:trending_keywords, trends_data.trending_keywords)
     |> assign(:trends_summary, calculate_trends_summary(trends_data))
     |> assign(:last_update, DateTime.utc_now())}
  end

  def handle_info({:trends_update, trends_data}, socket) do
    {:noreply,
     socket
     |> assign(:political_trends, trends_data.political || [])
     |> assign(:global_trends, trends_data.global || [])
     |> assign(:trending_keywords, trends_data.trending_keywords || [])
     |> assign(:trends_summary, calculate_trends_summary(trends_data))
     |> assign(:last_update, DateTime.utc_now())}
  end

  @impl true
  def handle_event("select_region", %{"region" => region}, socket) do
    {:noreply, assign(socket, :selected_region, region)}
  end

  def handle_event("refresh_trends", _params, socket) do
    send(self(), :fetch_trends)
    {:noreply, assign(socket, :loading, true)}
  end

  defp fetch_initial_trends_data do
    # Fetch from Google Trends RSS
    political_trends = case GlobalPulse.Services.GoogleTrendsRSS.fetch_daily_trends() do
      {:ok, trends} -> 
        Logger.info("📈 Loaded #{length(trends)} political trends")
        trends
      _ -> 
        Logger.warning("📈 Google Trends RSS unavailable, using fallback")
        fallback_political_trends()
    end

    # Fetch global trends (use realtime trends as global trends)
    global_trends = case GlobalPulse.Services.GoogleTrendsRSS.fetch_realtime_trends() do
      {:ok, trends} -> trends
      _ -> fallback_global_trends()
    end

    # Extract trending keywords from trends
    trending_keywords = extract_trending_keywords(political_trends ++ global_trends)

    # Group by regions (simulated for now)
    regional_trends = group_trends_by_region(global_trends)

    %{
      political: political_trends,
      global: global_trends,
      regional: regional_trends,
      trending_keywords: trending_keywords
    }
  end

  defp extract_trending_keywords(trends) do
    trends
    |> Enum.flat_map(fn trend -> 
      # Use title as the main keyword, since Google Trends RSS doesn't have a 'keyword' field
      main_keyword = Map.get(trend, :keyword, Map.get(trend, :title, ""))
      related_queries = Map.get(trend, :related_queries, [])
      [main_keyword | related_queries]
    end)
    |> Enum.reject(&(&1 == "" || is_nil(&1)))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(20)
    |> Enum.map(fn {keyword, count} ->
      %{
        keyword: keyword,
        frequency: count,
        category: categorize_keyword(keyword),
        trend_direction: :rand.uniform(3) - 2 # -1, 0, 1 for down, stable, up
      }
    end)
  end

  defp categorize_keyword(keyword) do
    keyword_lower = String.downcase(keyword)
    cond do
      String.contains?(keyword_lower, ["election", "vote", "politics", "government"]) -> :political
      String.contains?(keyword_lower, ["economy", "market", "stock", "crypto"]) -> :economic
      String.contains?(keyword_lower, ["health", "covid", "vaccine", "pandemic"]) -> :health
      String.contains?(keyword_lower, ["climate", "environment", "energy"]) -> :environmental
      String.contains?(keyword_lower, ["war", "conflict", "military"]) -> :conflict
      true -> :general
    end
  end

  defp group_trends_by_region(trends) do
    # Group trends by geographic indicators in the data
    regions = ["global", "americas", "europe", "asia", "africa"]
    
    Enum.map(regions, fn region ->
      region_trends = trends
      |> Enum.filter(fn trend ->
        # Simple region detection based on content
        content = String.downcase("#{trend.title} #{Map.get(trend, :description, "")}")
        case region do
          "americas" -> String.contains?(content, ["usa", "america", "canada", "mexico", "brazil"])
          "europe" -> String.contains?(content, ["europe", "uk", "germany", "france", "italy"])
          "asia" -> String.contains?(content, ["china", "japan", "india", "korea", "asia"])
          "africa" -> String.contains?(content, ["africa", "nigeria", "south africa"])
          _ -> true # global gets everything
        end
      end)
      |> Enum.take(10)

      %{
        region: region,
        trends: region_trends,
        total_volume: Enum.sum(Enum.map(region_trends, &(&1.interest_score || 0)))
      }
    end)
  end

  defp calculate_trends_summary(trends_data) do
    all_trends = (trends_data.political || []) ++ (trends_data.global || [])
    
    total_trends = length(all_trends)
    
    # Calculate average interest score
    avg_interest = if total_trends > 0 do
      all_trends
      |> Enum.map(&(&1.interest_score || 0))
      |> Enum.sum()
      |> Kernel./(total_trends)
      |> Float.round(1)
    else
      0.0
    end

    # Count trending keywords by category
    keyword_categories = (trends_data.trending_keywords || [])
    |> Enum.group_by(&(&1.category))
    |> Enum.map(fn {category, keywords} -> {category, length(keywords)} end)
    |> Map.new()

    # Find highest interest trend
    top_trend = all_trends
    |> Enum.max_by(&(&1.interest_score || 0), fn -> %{title: "None", interest_score: 0} end)

    %{
      total_trends: total_trends,
      avg_interest_score: avg_interest,
      keyword_categories: keyword_categories,
      top_trend: top_trend,
      last_updated: DateTime.utc_now()
    }
  end

  defp fallback_political_trends do
    [
      %{
        title: "Election Security",
        keyword: "election security",
        interest_score: 75,
        change_24h: 12.5,
        search_volume: "50K - 100K",
        category: :political,
        sentiment_indicator: :neutral,
        sentiment_shift: :rising,
        related_queries: ["voting security", "election integrity"],
        timestamp: DateTime.utc_now()
      },
      %{
        title: "Congressional Approval",
        keyword: "congress approval",
        interest_score: 68,
        change_24h: -5.2,
        search_volume: "25K - 50K",
        category: :political,
        sentiment_indicator: :negative,
        sentiment_shift: :falling,
        related_queries: ["congress rating", "approval polls"],
        timestamp: DateTime.utc_now()
      },
      %{
        title: "Climate Policy",
        keyword: "climate policy",
        interest_score: 62,
        change_24h: 8.1,
        search_volume: "30K - 60K",
        category: :environmental,
        sentiment_indicator: :positive,
        sentiment_shift: :surge,
        related_queries: ["environmental policy", "green legislation"],
        timestamp: DateTime.utc_now()
      }
    ]
  end

  defp fallback_global_trends do
    [
      %{
        title: "Global Economy",
        keyword: "global economy",  # Keep for backwards compatibility
        interest_score: 82,
        change_24h: 3.7,
        search_volume: "100K - 1M",
        category: :economic,
        sentiment_indicator: :neutral,
        sentiment_shift: :stable,
        related_queries: ["world economy", "international markets"],
        timestamp: DateTime.utc_now()
      },
      %{
        title: "International Relations",
        keyword: "international relations",  # Keep for backwards compatibility
        interest_score: 71,
        change_24h: -2.1,
        search_volume: "75K - 150K",
        category: :political,
        sentiment_indicator: :neutral,
        sentiment_shift: :stable,
        related_queries: ["diplomacy", "foreign policy"],
        timestamp: DateTime.utc_now()
      }
    ]
  end

  # Helper functions for display
  defp interest_score_color(score) when score >= 80, do: "text-red-400"
  defp interest_score_color(score) when score >= 60, do: "text-orange-400"
  defp interest_score_color(score) when score >= 40, do: "text-yellow-400"
  defp interest_score_color(_), do: "text-gray-400"

  defp sentiment_shift_color(:surge), do: "text-red-400"
  defp sentiment_shift_color(:rising), do: "text-green-400"
  defp sentiment_shift_color(:falling), do: "text-orange-400"
  defp sentiment_shift_color(:crash), do: "text-red-500"
  defp sentiment_shift_color(_), do: "text-gray-400"

  defp sentiment_shift_icon(:surge), do: "🚀"
  defp sentiment_shift_icon(:rising), do: "📈"
  defp sentiment_shift_icon(:falling), do: "📉"
  defp sentiment_shift_icon(:crash), do: "💥"
  defp sentiment_shift_icon(_), do: "➡️"

  defp category_color(:political), do: "bg-red-500/20 text-red-400"
  defp category_color(:economic), do: "bg-green-500/20 text-green-400"
  defp category_color(:health), do: "bg-blue-500/20 text-blue-400"
  defp category_color(:environmental), do: "bg-emerald-500/20 text-emerald-400"
  defp category_color(:conflict), do: "bg-red-600/20 text-red-500"
  defp category_color(_), do: "bg-gray-500/20 text-gray-400"

  defp trend_direction_icon(1), do: "↗️"
  defp trend_direction_icon(-1), do: "↘️"
  defp trend_direction_icon(_), do: "→"

  defp format_change(change) when change > 0, do: "+#{Float.round(change, 1)}%"
  defp format_change(change), do: "#{Float.round(change, 1)}%"

  defp format_time(nil), do: "Never"
  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S UTC")
  end
end