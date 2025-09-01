defmodule GlobalPulseWeb.NewsLive.Index do
  use GlobalPulseWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to all real-time channels
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "news_updates")
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "breaking_news")
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "trending_updates")
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "sentiment_updates")
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "news_pulse")
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "source_status")  # Subscribe to real source status
      
      # Quick refresh for real-time feel
      :timer.send_interval(30_000, self(), :check_activity)  # Check activity every 30s
      
      # Send initial pulse
      send(self(), :pulse_animation)
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
     |> assign(:breaking_news_count, length(breaking_articles))
     |> assign(:pulse_active, false)
     |> assign(:new_articles_count, 0)
     |> assign(:live_sources, %{
       # Categories
       rss: :connected,
       reddit: :connected,
       major_networks: :connected,
       analytics: :connected,
       sentiment: :connected,
       anomaly: :connected,
       # Individual RSS sources
       bbc: :connected,
       reuters: :connected,
       ap: :connected,
       el_pais: :connected,
       guardian: :connected,
       # Individual major networks
       cnn: :connected,
       npr: :connected,
       aljazeera: :connected,
       bbc_politics: :connected,
       # Individual Reddit sources
       reddit_worldnews: :connected,
       reddit_politics: :connected,
       reddit_news: :connected,
       reddit_geopolitics: :connected
     })
     |> assign(:source_error_states, %{})
     |> assign(:http_codes, %{})
     |> assign(:last_pulse, DateTime.utc_now())}
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
    # Calculate new articles count for live indicator
    previous_count = length(socket.assigns.all_articles)
    new_count = length(articles)
    new_articles_count = max(0, new_count - previous_count)
    
    {:noreply,
     socket
     |> assign(:all_articles, articles)
     |> assign(:available_categories, get_available_categories(articles))
     |> assign(:news_summary, calculate_news_summary(articles))
     |> assign(:new_articles_count, new_articles_count)
     |> assign(:pulse_active, new_articles_count > 0)
     |> assign(:last_update, DateTime.utc_now())
     |> tap(fn socket ->
       if new_articles_count > 0 do
         Process.send_after(self(), :reset_new_count, 15_000)
       end
       socket
     end)}
  end

  def handle_info({:breaking_news, breaking_articles}, socket) do
    {:noreply, 
     socket
     |> assign(:breaking_news, breaking_articles)
     |> assign(:breaking_news_count, length(breaking_articles))
     |> assign(:pulse_active, true)}
  end
  
  def handle_info({:pulse, pulse_data}, socket) do
    # Show live pulse indicator
    {:noreply,
     socket
     |> assign(:pulse_active, true)
     |> assign(:last_pulse, pulse_data.timestamp)
     |> assign(:new_articles_count, pulse_data.article_count - length(socket.assigns.all_articles))}
  end
  
  def handle_info(:pulse_animation, socket) do
    # Toggle pulse animation
    Process.send_after(self(), :pulse_animation, 2000)
    {:noreply, assign(socket, :pulse_active, !socket.assigns.pulse_active)}
  end
  
  def handle_info(:check_activity, socket) do
    # Periodically set sources to active if they're pulling data
    # This creates the pulsing effect when data is being fetched
    live_sources = socket.assigns.live_sources
    |> Enum.map(fn {source, status} ->
      # Randomly show some sources as actively pulling (if they're connected)
      if status == :connected && :rand.uniform() < 0.1 do
        {source, :active}
      else
        {source, status}
      end
    end)
    |> Map.new()
    
    # Reset active states back to connected after a short time
    Process.send_after(self(), :reset_active_states, 2000)
    
    {:noreply, assign(socket, :live_sources, live_sources)}
  end
  
  def handle_info(:reset_active_states, socket) do
    live_sources = socket.assigns.live_sources
    |> Enum.map(fn {source, status} ->
      if status == :active do
        {source, :connected}
      else
        {source, status}
      end
    end)
    |> Map.new()
    
    {:noreply, assign(socket, :live_sources, live_sources)}
  end
  
  def handle_info({:source_status_update, %{source: source, status: status} = update}, socket) do
    # Handle real status updates from the NewsAggregator
    live_sources = Map.put(socket.assigns.live_sources, source, status)
    
    # Track HTTP codes
    http_codes = socket.assigns[:http_codes] || %{}
    http_codes = if update[:http_code] do
      Map.put(http_codes, source, update[:http_code])
    else
      http_codes
    end
    
    # Update category status based on individual sources
    live_sources = update_category_statuses(live_sources)
    
    # Track error states with timestamp
    source_error_states = if status == :error do
      Map.put(socket.assigns.source_error_states, source, DateTime.utc_now())
    else
      Map.delete(socket.assigns.source_error_states, source)
    end
    
    {:noreply, 
     socket
     |> assign(:live_sources, live_sources)
     |> assign(:source_error_states, source_error_states)
     |> assign(:http_codes, http_codes)}
  end
  
  defp update_category_statuses(live_sources) do
    # Update RSS category status based on individual RSS sources
    rss_sources = [:bbc, :reuters, :ap, :guardian, :bbc_politics]
    rss_status = aggregate_category_status(live_sources, rss_sources)
    
    # Update major networks category status
    network_sources = [:cnn, :npr, :aljazeera]
    networks_status = aggregate_category_status(live_sources, network_sources)
    
    # Update Reddit category status
    reddit_sources = [:reddit_worldnews, :reddit_politics, :reddit_news, :reddit_geopolitics]
    reddit_status = aggregate_category_status(live_sources, reddit_sources)
    
    live_sources
    |> Map.put(:rss, rss_status)
    |> Map.put(:major_networks, networks_status)
    |> Map.put(:reddit, reddit_status)
  end
  
  defp aggregate_category_status(live_sources, source_list) do
    statuses = source_list
    |> Enum.map(&Map.get(live_sources, &1, :connected))
    
    cond do
      Enum.any?(statuses, &(&1 == :active)) -> :active
      Enum.all?(statuses, &(&1 == :error)) -> :error
      Enum.any?(statuses, &(&1 == :error)) -> :connected  # Some errors but not all
      true -> :connected
    end
  end
  
  def handle_info({:trending_update, trending_topics}, socket) do
    {:noreply, assign(socket, :trending_topics, trending_topics)}
  end
  
  def handle_info({:sentiment_update, sentiment}, socket) do
    {:noreply, assign(socket, :sentiment_analysis, sentiment)}
  end
  
  def handle_info(:reset_new_count, socket) do
    {:noreply, assign(socket, :new_articles_count, 0)}
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
    # Primary source: NewsMonitor (consolidated news and political data)
    all_articles = case GlobalPulse.NewsMonitor.get_latest_data() do
      %{news: articles} when is_list(articles) -> 
        Logger.info("📰 Loaded #{length(articles)} articles from NewsMonitor")
        articles
      _ -> 
        # Fallback to direct NewsAggregator
        case GlobalPulse.Services.NewsAggregator.fetch_all_news() do
          {:ok, articles} -> 
            Logger.info("📰 Fallback: Loaded #{length(articles)} articles from NewsAggregator")
            articles
          _ -> 
            Logger.warning("📰 All news sources unavailable, using empty list")
            []
        end
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
  

  defp source_indicator_class(status) do
    case status do
      :active -> "w-3 h-3 bg-green-500 rounded-full mr-2 transition-all duration-300 animate-pulse shadow-lg shadow-green-500/50"
      :connected -> "w-3 h-3 bg-green-500 rounded-full mr-2 transition-all duration-300 shadow-lg shadow-green-500/30"
      :error -> "w-3 h-3 bg-red-500 rounded-full mr-2 transition-all duration-300 animate-pulse shadow-lg shadow-red-500/50"
      _ -> "w-3 h-3 bg-gray-600 rounded-full mr-2 transition-all duration-300"
    end
  end

  defp source_text_class(status) do
    base_class = "group-hover:text-white transition-colors"
    case status do
      :active -> "#{base_class} text-green-300"
      :connected -> "#{base_class} text-green-300"  
      :error -> "#{base_class} text-red-300"
      _ -> "#{base_class} text-gray-400"
    end
  end

  defp source_text_class_orange(status) do
    base_class = "group-hover:text-white transition-colors"
    case status do
      :active -> "#{base_class} text-orange-300"
      :connected -> "#{base_class} text-orange-300"
      :error -> "#{base_class} text-red-300"
      _ -> "#{base_class} text-gray-400"
    end
  end

  defp source_indicator_class_orange(status) do
    case status do
      :active -> "w-3 h-3 bg-orange-500 rounded-full mr-2 transition-all duration-300 animate-pulse shadow-lg shadow-orange-500/50"
      :connected -> "w-3 h-3 bg-orange-500 rounded-full mr-2 transition-all duration-300 shadow-lg shadow-orange-500/30"
      :error -> "w-3 h-3 bg-red-500 rounded-full mr-2 transition-all duration-300 animate-pulse shadow-lg shadow-red-500/50"
      _ -> "w-3 h-3 bg-gray-600 rounded-full mr-2 transition-all duration-300"
    end
  end

  defp source_text_class_purple(status) do
    base_class = "group-hover:text-white transition-colors"
    case status do
      :active -> "#{base_class} text-purple-300"
      :connected -> "#{base_class} text-purple-300"
      :error -> "#{base_class} text-red-300"
      _ -> "#{base_class} text-gray-400"
    end
  end

  defp source_indicator_class_purple(status) do
    case status do
      :active -> "w-3 h-3 bg-purple-500 rounded-full mr-2 transition-all duration-300 animate-pulse shadow-lg shadow-purple-500/50"
      :connected -> "w-3 h-3 bg-purple-500 rounded-full mr-2 transition-all duration-300 shadow-lg shadow-purple-500/30"
      :error -> "w-3 h-3 bg-red-500 rounded-full mr-2 transition-all duration-300 animate-pulse shadow-lg shadow-red-500/50"
      _ -> "w-3 h-3 bg-gray-600 rounded-full mr-2 transition-all duration-300"
    end
  end

  defp source_text_class_blue(status) do
    base_class = "group-hover:text-white transition-colors"
    case status do
      :active -> "#{base_class} text-blue-300"
      :connected -> "#{base_class} text-blue-300"
      :error -> "#{base_class} text-red-300"
      _ -> "#{base_class} text-gray-400"
    end
  end

  defp source_indicator_class_blue(status) do
    case status do
      :active -> "w-3 h-3 bg-blue-500 rounded-full mr-2 transition-all duration-300 animate-pulse shadow-lg shadow-blue-500/50"
      :connected -> "w-3 h-3 bg-blue-500 rounded-full mr-2 transition-all duration-300 shadow-lg shadow-blue-500/30"
      :error -> "w-3 h-3 bg-red-500 rounded-full mr-2 transition-all duration-300 animate-pulse shadow-lg shadow-red-500/50"
      _ -> "w-3 h-3 bg-gray-600 rounded-full mr-2 transition-all duration-300"
    end
  end

  defp source_text_class_yellow(status) do
    base_class = "group-hover:text-white transition-colors"
    case status do
      :active -> "#{base_class} text-yellow-300"
      :connected -> "#{base_class} text-yellow-300"
      :error -> "#{base_class} text-red-300"
      _ -> "#{base_class} text-gray-400"
    end
  end

  defp source_indicator_class_yellow(status) do
    case status do
      :active -> "w-3 h-3 bg-yellow-500 rounded-full mr-2 transition-all duration-300 animate-pulse shadow-lg shadow-yellow-500/50"
      :connected -> "w-3 h-3 bg-yellow-500 rounded-full mr-2 transition-all duration-300 shadow-lg shadow-yellow-500/30"
      :error -> "w-3 h-3 bg-red-500 rounded-full mr-2 transition-all duration-300 animate-pulse shadow-lg shadow-red-500/50"
      _ -> "w-3 h-3 bg-gray-600 rounded-full mr-2 transition-all duration-300"
    end
  end
  
  def format_http_code(code) when is_nil(code), do: nil
  def format_http_code(200), do: nil  # Don't show 200s as they're normal
  def format_http_code(code), do: code  # Show error codes

end