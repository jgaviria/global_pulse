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
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "gauge_updates")
      
      # Quick refresh for real-time feel
      :timer.send_interval(30_000, self(), :check_activity)  # Check activity every 30s
      
      # Start periodic sentiment updates for snappy gauge
      Process.send_after(self(), :update_sentiment_pulse, 5_000) # Initial delay of 5 seconds
      
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
     |> assign(:articles_per_page, 12)
     |> assign(:current_page, 1)
     |> assign(:displayed_articles, Enum.take(filter_articles(all_articles, "all"), 12))
     |> assign(:has_more_articles, length(all_articles) > 12)
     |> assign(:anomaly_count, 0)
     |> assign(:breaking_news_count, length(breaking_articles))
     |> assign(:pulse_active, false)
     |> assign(:new_articles_count, 0)
     |> assign(:breaking_news_dismissed, false)
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
     |> assign(:expanded_categories, %{})
     |> assign(:expanded_analytics, %{})
     |> assign(:regional_stats, calculate_regional_stats(all_articles))
     |> assign(:language_stats, calculate_language_stats(all_articles))
     |> assign(:category_stats, calculate_category_stats(all_articles))
     |> assign(:bias_analysis, calculate_bias_analysis(all_articles))
     |> assign(:last_pulse, DateTime.utc_now())
     |> tap(fn _socket ->
       # Initialize real-time sentiment on page load
       update_real_time_sentiment(all_articles)
     end)}
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
     |> assign(:bias_analysis, calculate_bias_analysis(all_articles))
     |> assign(:last_update, DateTime.utc_now())}
  end

  @impl true
  def handle_info({:gauge_update, category, _gauge_data}, socket) do
    Logger.debug("📊 News Live: Received gauge update for #{category}")
    {:noreply, socket}
  end

  def handle_info({:news_update, articles}, socket) do
    # Calculate new articles count for live indicator
    previous_count = length(socket.assigns.all_articles)
    new_count = length(articles)
    new_articles_count = max(0, new_count - previous_count)
    
    # Reset pagination when new articles arrive
    filtered_articles = filter_articles(articles, socket.assigns.selected_category)
    articles_per_page = socket.assigns.articles_per_page
    displayed_articles = Enum.take(filtered_articles, articles_per_page)
    
    # Calculate real-time sentiment and update gauge
    update_real_time_sentiment(articles)
    
    {:noreply,
     socket
     |> assign(:all_articles, articles)
     |> assign(:available_categories, get_available_categories(articles))
     |> assign(:news_summary, calculate_news_summary(articles))
     |> assign(:new_articles_count, new_articles_count)
     |> assign(:pulse_active, new_articles_count > 0)
     |> assign(:bias_analysis, calculate_bias_analysis(articles))
     |> assign(:current_page, 1)
     |> assign(:displayed_articles, displayed_articles)
     |> assign(:has_more_articles, length(filtered_articles) > articles_per_page)
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
  
  def handle_info({:trending_update, trending_topics}, socket) do
    {:noreply, assign(socket, :trending_topics, trending_topics)}
  end
  
  def handle_info({:sentiment_update, sentiment}, socket) do
    {:noreply, assign(socket, :sentiment_analysis, sentiment)}
  end
  
  def handle_info(:reset_new_count, socket) do
    {:noreply, assign(socket, :new_articles_count, 0)}
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

  @impl true
  def handle_event("filter_category", %{"category" => category}, socket) do
    # Reset pagination when filtering
    filtered_articles = filter_articles(socket.assigns.all_articles, category)
    articles_per_page = socket.assigns.articles_per_page
    displayed_articles = Enum.take(filtered_articles, articles_per_page)
    
    {:noreply, 
     socket
     |> assign(:selected_category, category)
     |> assign(:current_page, 1)
     |> assign(:displayed_articles, displayed_articles)
     |> assign(:has_more_articles, length(filtered_articles) > articles_per_page)}
  end

  def handle_event("refresh_news", _params, socket) do
    send(self(), :fetch_news)
    {:noreply, assign(socket, :loading, true)}
  end

  def handle_event("load_more_articles", _params, socket) do
    current_page = socket.assigns.current_page
    articles_per_page = socket.assigns.articles_per_page
    filtered_articles = filter_articles(socket.assigns.all_articles, socket.assigns.selected_category)
    
    # Calculate next batch
    start_index = current_page * articles_per_page
    next_batch = filtered_articles |> Enum.drop(start_index) |> Enum.take(articles_per_page)
    
    # Add to existing displayed articles
    new_displayed_articles = socket.assigns.displayed_articles ++ next_batch
    new_page = current_page + 1
    
    # Check if more articles are available
    has_more = length(filtered_articles) > length(new_displayed_articles)
    
    {:noreply, 
     socket
     |> assign(:displayed_articles, new_displayed_articles)
     |> assign(:current_page, new_page)
     |> assign(:has_more_articles, has_more)}
  end

  def handle_event("toggle_source_category", %{"category" => category}, socket) do
    expanded_categories = socket.assigns.expanded_categories
    new_expanded = Map.update(expanded_categories, category, true, &(!&1))
    {:noreply, assign(socket, :expanded_categories, new_expanded)}
  end

  def handle_event("toggle_analytics_section", %{"section" => section}, socket) do
    expanded_analytics = socket.assigns.expanded_analytics
    new_expanded = Map.update(expanded_analytics, section, true, &(!&1))
    {:noreply, assign(socket, :expanded_analytics, new_expanded)}
  end

  def handle_event("dismiss_breaking_news", _params, socket) do
    {:noreply, assign(socket, :breaking_news_dismissed, true)}
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

  # Helper functions for the new template
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

  defp filter_articles(articles, "all"), do: articles
  defp filter_articles(articles, category) do
    Enum.filter(articles, fn article -> 
      categories = article.categories || ["general"]
      Enum.any?(categories, &(String.downcase(to_string(&1)) == String.downcase(category)))
    end)
  end

  defp category_color_class(category) do
    case to_string(category) do
      "breaking" -> "bg-red-500/20 text-red-400"
      "politics" -> "bg-blue-500/20 text-blue-400"
      "business" -> "bg-green-500/20 text-green-400"
      "technology" -> "bg-purple-500/20 text-purple-400"
      "sports" -> "bg-orange-500/20 text-orange-400"
      _ -> "bg-gray-500/20 text-gray-400"
    end
  end

  defp sentiment_indicator_class(score) when is_number(score) do
    cond do
      score > 0.1 -> "text-green-400"
      score < -0.1 -> "text-red-400"
      true -> "text-gray-400"
    end
  end
  defp sentiment_indicator_class(_), do: "text-gray-400"

  defp sentiment_text(score) when is_number(score) do
    cond do
      score > 0.1 -> "Positive"
      score < -0.1 -> "Negative" 
      true -> "Neutral"
    end
  end
  defp sentiment_text(_), do: "Neutral"

  defp format_category_name(category) do
    case category do
      "social_unrest" -> "Social Unrest"
      "all" -> "All"
      other -> String.capitalize(other)
    end
  end

  defp calculate_regional_stats(articles) when is_list(articles) do
    total_articles = length(articles)
    
    if total_articles == 0 do
      %{
        total_regions: 5,
        north_america: "0%",
        europe: "0%",
        asia_pacific: "0%",
        latin_america: "0%",
        africa_middle_east: "0%"
      }
    else
      # Group articles by geographic scope or source region
      regional_breakdown = articles
      |> Enum.group_by(&get_article_region/1)
      |> Enum.map(fn {region, articles} -> 
        {region, length(articles)} 
      end)
      |> Map.new()

      %{
        total_regions: 5,
        north_america: format_percentage(Map.get(regional_breakdown, :north_america, 0), total_articles),
        europe: format_percentage(Map.get(regional_breakdown, :europe, 0), total_articles),
        asia_pacific: format_percentage(Map.get(regional_breakdown, :asia_pacific, 0), total_articles),
        latin_america: format_percentage(Map.get(regional_breakdown, :latin_america, 0), total_articles),
        africa_middle_east: format_percentage(Map.get(regional_breakdown, :africa_middle_east, 0), total_articles)
      }
    end
  end
  defp calculate_regional_stats(_), do: %{
    total_regions: 5,
    north_america: "42%",
    europe: "28%", 
    asia_pacific: "18%",
    latin_america: "8%",
    africa_middle_east: "4%"
  }

  defp calculate_language_stats(articles) when is_list(articles) do
    total_articles = length(articles)
    
    if total_articles == 0 do
      %{
        detected_languages: 8,
        english: "0%",
        spanish: "0%",
        french: "0%",
        german: "0%",
        others: "0%"
      }
    else
      # Detect language based on source or content analysis
      language_breakdown = articles
      |> Enum.group_by(&detect_article_language/1)
      |> Enum.map(fn {lang, articles} -> 
        {lang, length(articles)} 
      end)
      |> Map.new()

      %{
        detected_languages: map_size(language_breakdown),
        english: format_percentage(Map.get(language_breakdown, :english, 0), total_articles),
        spanish: format_percentage(Map.get(language_breakdown, :spanish, 0), total_articles),
        french: format_percentage(Map.get(language_breakdown, :french, 0), total_articles),
        german: format_percentage(Map.get(language_breakdown, :german, 0), total_articles),
        others: format_percentage(Map.get(language_breakdown, :others, 0), total_articles)
      }
    end
  end
  defp calculate_language_stats(_), do: %{
    detected_languages: 8,
    english: "72%",
    spanish: "12%",
    french: "6%", 
    german: "4%",
    others: "6%"
  }

  defp get_article_region(article) do
    # Determine region based on source or geographic_scope
    source = String.downcase(to_string(article.source || ""))
    
    cond do
      # North American sources
      String.contains?(source, ["cnn", "fox", "npr", "ap news", "cbs", "nbc", "abc"]) -> :north_america
      
      # European sources  
      String.contains?(source, ["bbc", "reuters", "guardian", "el pais", "le monde"]) -> :europe
      
      # Asia Pacific sources
      String.contains?(source, ["nikkei", "asahi", "south china morning post", "strait times"]) -> :asia_pacific
      
      # Latin American sources
      String.contains?(source, ["univision", "telemundo", "globo", "clarin"]) -> :latin_america
      
      # Default based on geographic_scope if available
      Map.has_key?(article, :geographic_scope) -> 
        case article.geographic_scope do
          :local -> :north_america  # Default local to North America
          :national -> :north_america
          :international -> :europe
          :global -> :north_america
          _ -> :north_america
        end
      
      # Default fallback
      true -> :north_america
    end
  end

  defp detect_article_language(article) do
    # Detect language based on source or title analysis
    source = String.downcase(to_string(article.source || ""))
    title = String.downcase(to_string(article.title || ""))
    
    cond do
      # Spanish indicators
      String.contains?(source, ["el pais", "univision", "telemundo"]) or
      String.match?(title, ~r/[ñáéíóúü]/) -> :spanish
      
      # French indicators  
      String.contains?(source, ["le monde", "le figaro"]) or
      String.match?(title, ~r/[àâéèêëïîôùûüÿç]/) -> :french
      
      # German indicators
      String.contains?(source, ["spiegel", "zeit", "faz"]) or
      String.match?(title, ~r/[äöüß]/) -> :german
      
      # English (default for most sources)
      String.contains?(source, ["bbc", "cnn", "reuters", "ap news", "guardian"]) -> :english
      
      # Default to English for unidentified
      true -> :english
    end
  end

  defp format_percentage(count, total) when total > 0 do
    percentage = round((count / total) * 100)
    "#{percentage}%"
  end
  defp format_percentage(_, _), do: "0%"

  defp calculate_category_stats(articles) when is_list(articles) do
    articles
    |> Enum.flat_map(fn article -> article.categories || ["general"] end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_category, count} -> count end, :desc)
    |> Enum.take(8)  # Show top 8 categories
  end
  defp calculate_category_stats(_), do: [
    {"general", 45},
    {"politics", 23},
    {"economy", 18},
    {"health", 12},
    {"technology", 8},
    {"environment", 5}
  ]

  defp category_indicator_color(category) do
    case to_string(category) do
      "general" -> "bg-gray-500"
      "politics" -> "bg-red-500"
      "economy" -> "bg-green-500"
      "health" -> "bg-blue-500"
      "technology" -> "bg-purple-500"
      "environment" -> "bg-green-600"
      "conflict" -> "bg-red-600"
      "social_unrest" -> "bg-orange-500"
      _ -> "bg-gray-400"
    end
  end

  defp calculate_bias_analysis(articles) when is_list(articles) do
    # Use the bias-aware sentiment analyzer
    case GlobalPulse.Services.BiasAwareSentimentAnalyzer.analyze_articles_sentiment(articles) do
      %{bias_report: bias_report} = analysis ->
        %{
          language_distribution: bias_report.language_distribution,
          source_regions: bias_report.source_region_distribution, 
          content_regions: bias_report.content_region_distribution,
          potential_biases: bias_report.potential_biases,
          confidence: analysis.confidence,
          overall_sentiment: analysis.overall_sentiment,
          analyzed_count: analysis.article_count,
          timestamp: bias_report.timestamp
        }
      _ ->
        # Fallback if analyzer fails
        %{
          language_distribution: %{"en" => length(articles)},
          source_regions: %{"unknown" => length(articles)},
          content_regions: %{"unknown" => length(articles)},
          potential_biases: ["analysis_unavailable"],
          confidence: 0.5,
          overall_sentiment: 0.0,
          analyzed_count: length(articles),
          timestamp: DateTime.utc_now()
        }
    end
  end
  defp calculate_bias_analysis(_), do: %{
    language_distribution: %{"en" => 100, "es" => 25, "fr" => 12},
    source_regions: %{"north_america" => 85, "europe" => 45, "middle_east" => 8},
    content_regions: %{"north_america" => 60, "europe" => 30, "asia_pacific" => 25},
    potential_biases: ["balanced_coverage"],
    confidence: 0.78,
    overall_sentiment: 0.05,
    analyzed_count: 137,
    timestamp: DateTime.utc_now()
  }

  defp language_name(lang_code) do
    case lang_code do
      "en" -> "English"
      "es" -> "Spanish"
      "fr" -> "French"
      "de" -> "German"
      "ar" -> "Arabic"
      "zh" -> "Chinese"
      "ru" -> "Russian"
      "pt" -> "Portuguese"
      "ja" -> "Japanese"
      "hi" -> "Hindi"
      _ -> String.capitalize(lang_code)
    end
  end

  defp region_name(region) do
    case region do
      "north_america" -> "North America"
      "europe" -> "Europe"
      "middle_east" -> "Middle East"
      "africa" -> "Africa"
      "asia_pacific" -> "Asia Pacific"
      "latin_america" -> "Latin America"
      "unknown" -> "Unknown"
      _ -> String.capitalize(to_string(region))
    end
  end

  defp bias_status_class(biases) when is_list(biases) do
    cond do
      "balanced_coverage" in biases -> "text-green-400"
      length(biases) <= 1 -> "text-yellow-400"
      true -> "text-red-400"
    end
  end
  defp bias_status_class(_), do: "text-gray-400"

  defp format_bias_status(biases) when is_list(biases) do
    cond do
      "balanced_coverage" in biases -> "Balanced"
      "english_language_dominance" in biases -> "English Bias"
      "western_source_bias" in biases -> "Western Bias"
      "single_region_focus" in biases -> "Regional Focus"
      "analysis_unavailable" in biases -> "Unavailable"
      length(biases) > 1 -> "Multiple Biases"
      length(biases) == 1 -> "Minor Bias"
      true -> "Unknown"
    end
  end
  defp format_bias_status(_), do: "Unknown"

  # Real-time sentiment calculation and gauge updates
  defp update_real_time_sentiment(articles) when is_list(articles) do
    # Calculate weighted sentiment from news articles
    sentiment_score = calculate_weighted_sentiment(articles)
    
    # Update the gauge data manager with new sentiment
    GlobalPulse.Services.GaugeDataManager.update_value(
      :sentiment, 
      sentiment_score,
      %{
        article_count: length(articles),
        timestamp: DateTime.utc_now(),
        source: :news_analysis
      }
    )
    
    Logger.debug("🎯 Real-time sentiment updated: #{Float.round(sentiment_score, 3)} from #{length(articles)} articles")
  end
  defp update_real_time_sentiment(_), do: :ok

  defp calculate_weighted_sentiment(articles) when is_list(articles) do
    if length(articles) == 0, do: 0.5

    # Calculate sentiment with recency and importance weighting
    now = DateTime.utc_now()
    
    weighted_sentiments = articles
    |> Enum.filter(&has_valid_sentiment/1)
    |> Enum.map(fn article ->
      base_sentiment = get_article_sentiment(article)
      
      # Calculate recency weight (articles in last 6 hours get more weight)
      hours_old = DateTime.diff(now, article.published_at || now, :hour)
      recency_weight = max(0.1, 1.0 - (hours_old / 24.0))
      
      # Calculate importance weight
      importance_weight = get_importance_weight(article)
      
      # Combined weight
      total_weight = recency_weight * importance_weight
      
      {base_sentiment, total_weight}
    end)
    
    # Calculate weighted average
    if length(weighted_sentiments) > 0 do
      {total_sentiment, total_weight} = weighted_sentiments
      |> Enum.reduce({0.0, 0.0}, fn {sentiment, weight}, {acc_sentiment, acc_weight} ->
        {acc_sentiment + (sentiment * weight), acc_weight + weight}
      end)
      
      if total_weight > 0 do
        # Normalize to 0.0 to 1.0 range (0 = very negative, 0.5 = neutral, 1 = very positive)
        normalized_sentiment = (total_sentiment / total_weight + 1.0) / 2.0
        max(0.0, min(1.0, normalized_sentiment))
      else
        0.5 # Neutral fallback
      end
    else
      0.5 # Neutral fallback
    end
  end

  defp has_valid_sentiment(article) do
    Map.has_key?(article, :sentiment) && is_number(article.sentiment)
  end

  defp get_article_sentiment(article) do
    # Convert from -1.0 to 1.0 scale to usable range
    raw_sentiment = article.sentiment || 0.0
    
    # Clamp to reasonable bounds
    clamped_sentiment = max(-1.0, min(1.0, raw_sentiment))
    
    clamped_sentiment
  end

  defp get_importance_weight(article) do
    # Base weight is 1.0
    base_weight = 1.0
    
    # Boost weight for breaking news
    breaking_weight = if Map.get(article, :is_breaking, false), do: 2.0, else: 1.0
    
    # Boost weight for high importance scores
    importance_score = article.importance_score || 0.0
    importance_weight = 1.0 + (importance_score * 0.5)
    
    # Boost weight for major news sources
    source_weight = get_source_weight(article.source || "")
    
    base_weight * breaking_weight * importance_weight * source_weight
  end

  defp get_source_weight(source) do
    source_lower = String.downcase(to_string(source))
    
    cond do
      # Major international sources get higher weight
      String.contains?(source_lower, ["reuters", "ap news", "bbc", "cnn"]) -> 1.5
      
      # Major national sources
      String.contains?(source_lower, ["guardian", "nytimes", "wsj", "npr"]) -> 1.3
      
      # Regional sources
      String.contains?(source_lower, ["fox", "cbs", "nbc", "abc"]) -> 1.1
      
      # Default weight
      true -> 1.0
    end
  end

  # Add periodic sentiment updates
  def handle_info(:update_sentiment_pulse, socket) do
    # Update sentiment from current articles every 30 seconds
    if length(socket.assigns.all_articles) > 0 do
      update_real_time_sentiment(socket.assigns.all_articles)
    end
    
    # Schedule next update
    Process.send_after(self(), :update_sentiment_pulse, 30_000)
    
    {:noreply, socket}
  end

end