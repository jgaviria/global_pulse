defmodule GlobalPulseWeb.NewsLive.Index do
  use GlobalPulseWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "news_updates")
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "breaking_news")
      
      # Refresh news data every 30 seconds
      :timer.send_interval(30_000, self(), :fetch_news)
    end

    # Get initial news data
    {all_articles, breaking_articles} = fetch_initial_news_data()

    {:ok,
     socket
     |> assign(:page_title, "Global News Feed")
     |> assign(:active_tab, :news)
     |> assign(:last_update, DateTime.utc_now())
     |> assign(:all_articles, all_articles)
     |> assign(:breaking_news, breaking_articles)
     |> assign(:selected_category, "all")
     |> assign(:available_categories, get_available_categories(all_articles))
     |> assign(:news_summary, calculate_news_summary(all_articles))
     |> assign(:loading, false)
     |> assign(:anomaly_count, 0)
     |> assign(:breaking_news_count, length(breaking_articles))}
  end

  @impl true
  def handle_info(:fetch_news, socket) do
    Logger.debug("🔄 Refreshing news data...")
    {all_articles, breaking_articles} = fetch_initial_news_data()
    
    {:noreply,
     socket
     |> assign(:all_articles, all_articles)
     |> assign(:breaking_news, breaking_articles)
     |> assign(:available_categories, get_available_categories(all_articles))
     |> assign(:news_summary, calculate_news_summary(all_articles))
     |> assign(:breaking_news_count, length(breaking_articles))
     |> assign(:last_update, DateTime.utc_now())}
  end

  def handle_info({:news_update, articles}, socket) do
    {:noreply,
     socket
     |> assign(:all_articles, articles)
     |> assign(:available_categories, get_available_categories(articles))
     |> assign(:news_summary, calculate_news_summary(articles))
     |> assign(:last_update, DateTime.utc_now())}
  end

  def handle_info({:breaking_news, breaking_articles}, socket) do
    {:noreply, 
     socket
     |> assign(:breaking_news, breaking_articles)
     |> assign(:breaking_news_count, length(breaking_articles))}
  end

  @impl true
  def handle_event("filter_category", %{"category" => category}, socket) do
    {:noreply, assign(socket, :selected_category, category)}
  end

  def handle_event("refresh_news", _params, socket) do
    send(self(), :fetch_news)
    {:noreply, assign(socket, :loading, true)}
  end

  defp fetch_initial_news_data do
    # Fetch from NewsAggregator
    all_articles = case GlobalPulse.Services.NewsAggregator.fetch_all_news() do
      {:ok, articles} -> 
        Logger.info("📰 Loaded #{length(articles)} articles from NewsAggregator")
        articles
      _ -> 
        Logger.warning("📰 NewsAggregator unavailable, using empty list")
        []
    end

    # Fetch breaking news from LiveNewsFeed
    breaking_articles = case GlobalPulse.Services.LiveNewsFeed.fetch_breaking_news() do
      {:ok, breaking} -> 
        Logger.info("🚨 Loaded #{length(breaking)} breaking news items")
        breaking
      _ -> []
    end

    {all_articles, breaking_articles}
  end

  defp get_available_categories(articles) do
    categories = articles
    |> Enum.flat_map(&(&1.categories || ["general"]))
    |> Enum.uniq()
    |> Enum.sort()

    ["all" | categories]
  end

  defp calculate_news_summary(articles) do
    total_articles = length(articles)
    
    # Sentiment breakdown
    sentiment_breakdown = articles
    |> Enum.group_by(fn article -> 
      sentiment = article.sentiment || 0
      cond do
        sentiment > 0.2 -> :positive
        sentiment < -0.2 -> :negative
        true -> :neutral
      end
    end)
    |> Enum.map(fn {sentiment, articles} -> {sentiment, length(articles)} end)
    |> Map.new()

    # Category breakdown
    category_breakdown = articles
    |> Enum.flat_map(&(&1.categories || ["general"]))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(5)

    # Source breakdown
    source_breakdown = articles
    |> Enum.map(&(&1.source))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(5)

    # High importance articles
    high_importance_count = articles
    |> Enum.count(&((&1.importance_score || 0) > 0.7))

    %{
      total_articles: total_articles,
      sentiment_breakdown: sentiment_breakdown,
      category_breakdown: category_breakdown,
      source_breakdown: source_breakdown,
      high_importance_count: high_importance_count,
      last_updated: DateTime.utc_now()
    }
  end

  defp filter_articles_by_category(articles, "all"), do: articles
  defp filter_articles_by_category(articles, category) do
    Enum.filter(articles, fn article ->
      category in (article.categories || [])
    end)
  end

  defp format_time_ago(datetime) when is_nil(datetime), do: "Unknown"
  defp format_time_ago(datetime) do
    diff_seconds = DateTime.diff(DateTime.utc_now(), datetime, :second)
    
    cond do
      diff_seconds < 60 -> "#{diff_seconds}s ago"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> "#{div(diff_seconds, 86400)}d ago"
    end
  end

  defp news_sentiment_color(sentiment) when sentiment > 0.2, do: "text-green-400"
  defp news_sentiment_color(sentiment) when sentiment < -0.2, do: "text-red-400"
  defp news_sentiment_color(_), do: "text-yellow-400"

  defp news_sentiment_background(sentiment) when sentiment > 0.2, do: "bg-green-500/20"
  defp news_sentiment_background(sentiment) when sentiment < -0.2, do: "bg-red-500/20"
  defp news_sentiment_background(_), do: "bg-yellow-500/20"

  defp importance_color(score) when score > 0.8, do: "text-red-400"
  defp importance_color(score) when score > 0.6, do: "text-orange-400"
  defp importance_color(_), do: "text-gray-400"

  defp threat_level_color(level) when level >= 70, do: "bg-red-500"
  defp threat_level_color(level) when level >= 40, do: "bg-orange-500"
  defp threat_level_color(_), do: "bg-green-500"

  defp category_badge_color(category) do
    case category do
      "politics" -> "bg-red-500/20 text-red-400"
      "conflict" -> "bg-red-600/20 text-red-500"
      "economy" -> "bg-green-500/20 text-green-400"
      "health" -> "bg-blue-500/20 text-blue-400"
      "environment" -> "bg-emerald-500/20 text-emerald-400"
      "technology" -> "bg-purple-500/20 text-purple-400"
      "social_unrest" -> "bg-orange-500/20 text-orange-400"
      _ -> "bg-gray-500/20 text-gray-400"
    end
  end

  defp urgency_badge(urgency) do
    case urgency do
      :immediate -> "bg-red-500/20 text-red-400 animate-pulse"
      :high -> "bg-orange-500/20 text-orange-400"
      :medium -> "bg-yellow-500/20 text-yellow-400"
      _ -> "bg-gray-500/20 text-gray-400"
    end
  end

  defp truncate_text(text, max_length \\ 150) do
    if String.length(text) <= max_length do
      text
    else
      String.slice(text, 0, max_length) <> "..."
    end
  end

  defp format_time(nil), do: "Never"
  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S UTC")
  end
end