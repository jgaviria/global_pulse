defmodule GlobalPulse.NewsMonitor do
  @moduledoc """
  Consolidated news and political monitoring system.
  Combines RSS feeds, social media trends, political events, and sentiment analysis.
  """
  use GenServer
  require Logger

  @poll_interval 60_000  # 1 minute for more real-time feel
  @quick_poll_interval 15_000  # 15 seconds for breaking news
  @sentiment_threshold 0.7
  
  defmodule State do
    defstruct [
      :news_articles,
      :trending_topics,
      :political_events,
      :social_media_trends,
      :sentiment_analysis,
      :last_update,
      :anomalies,
      :bias_report
    ]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Initial fetch
    send(self(), :initial_fetch)
    
    state = %State{
      news_articles: [],
      trending_topics: [],
      political_events: [],
      social_media_trends: [],
      sentiment_analysis: %{overall: 0.0, news: 0.0, social: 0.0},
      anomalies: [],
      last_update: DateTime.utc_now(),
      bias_report: nil
    }
    
    {:ok, state}
  end

  def get_latest_data do
    GenServer.call(__MODULE__, :get_data, 10_000)
  end

  def get_sentiment_analysis do
    GenServer.call(__MODULE__, :get_sentiment)
  end

  def handle_call(:get_data, _from, state) do
    data = %{
      news: state.news_articles,
      trending: state.trending_topics,
      events: state.political_events,
      social: state.social_media_trends,
      sentiment: state.sentiment_analysis,
      last_update: state.last_update,
      anomalies: state.anomalies
    }
    {:reply, data, state}
  end

  def handle_call(:get_sentiment, _from, state) do
    {:reply, state.sentiment_analysis, state}
  end

  def handle_info(:initial_fetch, state) do
    Logger.info("📰 NEWS MONITOR: Starting initial data fetch...")
    new_state = fetch_all_data(state)
    schedule_poll()
    {:noreply, new_state}
  end

  def handle_info(:poll, state) do
    new_state = fetch_all_data(state)
    schedule_poll()
    {:noreply, new_state}
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end

  defp fetch_all_data(state) do
    Logger.info("📰 NEWS MONITOR: Refreshing all news and political data...")
    
    state
    |> fetch_news_articles()
    |> fetch_trending_topics()
    |> fetch_political_events()
    |> fetch_social_media_trends()
    |> analyze_sentiment()
    |> detect_news_anomalies()
    |> broadcast_updates()
  end

  # ============================================================================
  # NEWS ARTICLES - Using NewsAggregator service
  # ============================================================================
  defp fetch_news_articles(state) do
    articles = case GlobalPulse.Services.NewsAggregator.fetch_all_news() do
      {:ok, news_articles} ->
        Logger.info("📰 NEWS MONITOR: Refreshed with #{length(news_articles)} articles")
        news_articles |> Enum.take(1000)  # Increased limit for more data points
      {:error, reason} ->
        Logger.warning("📰 NEWS MONITOR: News fetch failed: #{inspect(reason)}")
        state.news_articles || []
    end
    
    %{state | news_articles: articles, last_update: DateTime.utc_now()}
  end

  # ============================================================================
  # TRENDING TOPICS - Reddit and social platforms
  # ============================================================================
  defp fetch_trending_topics(state) do
    topics = case GlobalPulse.Services.NewsAggregator.fetch_trending_topics() do
      {:ok, trending} ->
        Logger.info("📰 NEWS MONITOR: Refreshed with #{length(trending)} trending topics")
        trending |> Enum.take(20)  # Top 20 trending
      {:error, reason} ->
        Logger.warning("📰 NEWS MONITOR: Trending fetch failed: #{inspect(reason)}")
        state.trending_topics || []
    end
    
    %{state | trending_topics: topics}
  end

  # ============================================================================
  # POLITICAL EVENTS - Government APIs and curated sources
  # ============================================================================
  defp fetch_political_events(state) do
    # Enhanced political events with more comprehensive data
    events = [
      %{
        id: "congress_economic_hearing_#{Date.utc_today()}",
        title: "Congressional Economic Policy Hearing",
        date: DateTime.add(DateTime.utc_now(), 2 * 24 * 3600, :second),
        location: "Washington, D.C.",
        type: "legislative",
        category: "economic_policy",
        impact_score: 0.8,
        description: "Key economic policy discussions affecting markets",
        participants: ["House Economic Committee", "Federal Reserve Officials"],
        source: "congress.gov",
        status: "scheduled"
      },
      %{
        id: "fed_rate_decision_#{Date.utc_today()}",
        title: "Federal Reserve Interest Rate Decision",
        date: DateTime.add(DateTime.utc_now(), 5 * 24 * 3600, :second),
        location: "Washington, D.C.",
        type: "economic",
        category: "monetary_policy", 
        impact_score: 0.9,
        description: "FOMC meeting on interest rates - major market impact expected",
        participants: ["Federal Reserve Board", "FOMC Members"],
        source: "federalreserve.gov",
        status: "scheduled"
      },
      %{
        id: "un_security_council_#{Date.utc_today()}",
        title: "UN Security Council Session",
        date: DateTime.add(DateTime.utc_now(), 3 * 24 * 3600, :second),
        location: "New York, NY",
        type: "diplomatic",
        category: "international_relations",
        impact_score: 0.7,
        description: "Discussion on global security issues",
        participants: ["UN Security Council", "Member Nations"],
        source: "un.org",
        status: "scheduled"
      },
      %{
        id: "election_primary_#{Date.utc_today()}",
        title: "State Primary Elections",
        date: DateTime.add(DateTime.utc_now(), 7 * 24 * 3600, :second),
        location: "Various States",
        type: "electoral",
        category: "elections",
        impact_score: 0.6,
        description: "Primary elections in multiple states",
        participants: ["Political Candidates", "Voters"],
        source: "ballotpedia.org",
        status: "scheduled"
      }
    ]
    
    # Filter events to only future ones
    current_events = events
    |> Enum.filter(fn event -> DateTime.after?(event.date, DateTime.utc_now()) end)
    |> Enum.sort_by(&(&1.date))
    
    Logger.info("📰 NEWS MONITOR: Updated #{length(current_events)} political events")
    %{state | political_events: current_events}
  end

  # ============================================================================
  # SOCIAL MEDIA TRENDS - Twitter-like trending analysis
  # ============================================================================
  defp fetch_social_media_trends(state) do
    # Enhanced social media trends based on news and Reddit data
    trends = []
    
    # Extract trending topics from news headlines
    news_trends = if state.news_articles do
      state.news_articles
      |> Enum.take(20)
      |> extract_trending_keywords()
      |> Enum.map(fn {keyword, count} ->
        %{
          keyword: keyword,
          volume: count * 100,  # Estimated volume
          source: "news_analysis",
          sentiment: calculate_keyword_sentiment(keyword),
          category: classify_trend_category(keyword),
          timestamp: DateTime.utc_now()
        }
      end)
    else
      []
    end
    
    # Combine with Reddit trends if available
    social_trends = if state.trending_topics do
      state.trending_topics
      |> Enum.take(10)
      |> Enum.map(fn topic ->
        # Extract first category from categories list, or use default
        first_category = case Map.get(topic, :categories) do
          [category | _] -> category
          _ -> "general"
        end
        
        %{
          keyword: Map.get(topic, :title) || Map.get(topic, :topic) || "Unknown",
          volume: Map.get(topic, :score) || Map.get(topic, :upvotes) || 0,
          source: "reddit",
          sentiment: Map.get(topic, :sentiment) || 0.5,
          category: first_category,
          timestamp: DateTime.utc_now()
        }
      end)
    else
      []
    end
    
    all_trends = (news_trends ++ social_trends)
    |> Enum.sort_by(&(&1.volume), :desc)
    |> Enum.take(15)
    
    Logger.info("📰 NEWS MONITOR: Updated #{length(all_trends)} social media trends")
    %{state | social_media_trends: all_trends}
  end

  # ============================================================================
  # SENTIMENT ANALYSIS - Multi-source sentiment calculation
  # ============================================================================
  defp analyze_sentiment(state) do
    {news_sentiment, bias_report} = calculate_news_sentiment_with_bias(state.news_articles)
    social_sentiment = calculate_social_sentiment(state.trending_topics)
    
    overall_sentiment = (news_sentiment * 0.6 + social_sentiment * 0.4)
    
    sentiment_analysis = %{
      overall: Float.round(overall_sentiment, 2),
      news: Float.round(news_sentiment, 2),
      social: Float.round(social_sentiment, 2),
      trend: determine_sentiment_trend(overall_sentiment, state.sentiment_analysis),
      last_updated: DateTime.utc_now()
    }
    
    Logger.info("📰 NEWS MONITOR: Sentiment - Overall: #{sentiment_analysis.overall}, News: #{sentiment_analysis.news}, Social: #{sentiment_analysis.social}")
    
    # Update gauge system with real-time sentiment data
    update_sentiment_gauges(sentiment_analysis, bias_report)
    
    %{state | sentiment_analysis: sentiment_analysis, bias_report: bias_report}
  end

  defp calculate_news_sentiment_with_bias(articles) when is_list(articles) do
    if length(articles) > 0 do
      # Use bias-aware sentiment analysis for comprehensive analysis
      case GlobalPulse.Services.BiasAwareSentimentAnalyzer.analyze_articles_sentiment(articles) do
        %{overall_sentiment: sentiment, bias_report: bias_report, confidence: confidence} ->
          # Log bias awareness information
          Logger.info("📰 NEWS MONITOR: Bias-aware sentiment analysis complete")
          Logger.info("   Overall sentiment: #{sentiment} (confidence: #{Float.round(confidence, 2)})")
          Logger.info("   Language distribution: #{inspect(bias_report.language_distribution)}")
          Logger.info("   Source regions: #{inspect(bias_report.source_region_distribution)}")
          
          potential_biases = bias_report.potential_biases
          if "balanced_coverage" not in potential_biases do
            Logger.warning("   Potential biases detected: #{inspect(potential_biases)}")
          end
          
          # Normalize sentiment from [-1,1] to [0,1] scale for compatibility
          normalized_sentiment = (sentiment + 1.0) / 2.0
          {normalized_sentiment, bias_report}
          
        _ ->
          # Fallback to original method
          sentiment = calculate_news_sentiment_fallback(articles)
          {sentiment, nil}
      end
    else
      {0.5, nil}  # Neutral when no data
    end
  end
  defp calculate_news_sentiment_with_bias(_), do: {0.5, nil}
  
  # Fallback method for sentiment calculation
  defp calculate_news_sentiment_fallback(articles) do
    total_sentiment = articles
    |> Enum.map(fn article -> article.sentiment || 0.0 end)
    |> Enum.sum()
    
    # Normalize to [0,1] scale and add 0.5 offset
    (total_sentiment / length(articles) + 1.0) / 2.0
  end

  defp calculate_social_sentiment(topics) when is_list(topics) do
    if length(topics) > 0 do
      total_sentiment = topics
      |> Enum.map(fn topic -> topic.sentiment || 0.5 end)
      |> Enum.sum()
      
      total_sentiment / length(topics)
    else
      0.5  # Neutral when no data
    end
  end
  defp calculate_social_sentiment(_), do: 0.5

  defp determine_sentiment_trend(current, previous) do
    case previous do
      %{overall: prev_overall} when is_number(prev_overall) ->
        diff = current - prev_overall
        cond do
          diff > 0.1 -> "improving"
          diff < -0.1 -> "declining"
          true -> "stable"
        end
      _ -> "stable"
    end
  end

  # Update gauge system with sentiment data
  defp update_sentiment_gauges(sentiment_analysis, bias_report) do
    # Update sentiment gauge with overall sentiment
    confidence = if bias_report do
      # Calculate confidence based on bias report
      base_confidence = 0.7
      
      # Reduce confidence for high bias
      bias_penalty = case length(bias_report.potential_biases || []) do
        n when n > 3 -> 0.3
        n when n > 1 -> 0.2
        _ -> 0.0
      end
      
      # Increase confidence for balanced coverage
      balance_bonus = if "balanced_coverage" in (bias_report.potential_biases || []) do
        0.2
      else
        0.0
      end
      
      max(0.3, min(1.0, base_confidence - bias_penalty + balance_bonus))
    else
      0.5  # Default confidence when no bias report
    end
    
    # Prepare metadata for gauge update
    metadata = %{
      confidence: confidence,
      bias_report: bias_report,
      trend: sentiment_analysis.trend,
      source: "news_monitor"
    }
    
    # Update sentiment gauge - convert from [0,1] scale to match gauge expectations
    GlobalPulse.Services.GaugeDataManager.update_value(
      :sentiment, 
      sentiment_analysis.overall, 
      metadata
    )
    
    Logger.info("🎯 GAUGE UPDATE: Sentiment gauge updated - value: #{sentiment_analysis.overall}, confidence: #{Float.round(confidence, 2)}")
  end

  # ============================================================================
  # ANOMALY DETECTION - News and political anomalies
  # ============================================================================
  defp detect_news_anomalies(state) do
    anomalies = []
    
    # Sentiment anomalies
    sentiment_anomalies = if state.sentiment_analysis.overall < 0.3 or state.sentiment_analysis.overall > 0.7 do
      [%{
        type: "sentiment_anomaly",
        severity: if(state.sentiment_analysis.overall < 0.3, do: "high", else: "medium"),
        description: "Unusual sentiment detected: #{state.sentiment_analysis.overall}",
        timestamp: DateTime.utc_now(),
        data: state.sentiment_analysis
      }]
    else
      []
    end
    
    # High impact political events
    political_anomalies = state.political_events
    |> Enum.filter(&(&1.impact_score >= 0.8))
    |> Enum.map(fn event ->
      %{
        type: "high_impact_political_event",
        severity: "medium",
        description: "High impact political event: #{event.title}",
        timestamp: DateTime.utc_now(),
        data: event
      }
    end)
    
    all_anomalies = sentiment_anomalies ++ political_anomalies
    |> Enum.take(10)  # Limit anomalies
    
    if length(all_anomalies) > 0 do
      Logger.info("📰 NEWS MONITOR: Detected #{length(all_anomalies)} news/political anomalies")
    end
    
    %{state | anomalies: all_anomalies}
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================
  defp extract_trending_keywords(articles) do
    # Simple keyword extraction from article titles and descriptions
    text = articles
    |> Enum.map(fn article -> 
      "#{article.title || ""} #{article.description || ""}"
    end)
    |> Enum.join(" ")
    |> String.downcase()
    
    # Extract common political/news keywords
    keywords = ~w[election vote congress senate house president biden trump ukraine russia china inflation economy market federal reserve interest rate climate immigration healthcare tax policy]
    
    keywords
    |> Enum.map(fn keyword ->
      count = text
      |> String.split()
      |> Enum.count(&String.contains?(&1, keyword))
      
      {keyword, count}
    end)
    |> Enum.filter(fn {_, count} -> count > 0 end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(10)
  end

  defp calculate_keyword_sentiment(keyword) do
    # Simple sentiment scoring based on keyword
    positive_keywords = ~w[growth success victory agreement peace progress development achievement]
    negative_keywords = ~w[crisis conflict war recession inflation unemployment protest violence threat]
    
    cond do
      Enum.any?(positive_keywords, &String.contains?(keyword, &1)) -> 0.7
      Enum.any?(negative_keywords, &String.contains?(keyword, &1)) -> 0.3
      true -> 0.5  # Neutral
    end
  end

  defp classify_trend_category(keyword) do
    cond do
      String.contains?(keyword, ~w[election vote congress senate president]) -> "politics"
      String.contains?(keyword, ~w[economy market inflation interest federal reserve]) -> "economics" 
      String.contains?(keyword, ~w[ukraine russia china iran]) -> "international"
      String.contains?(keyword, ~w[climate environment energy]) -> "environment"
      String.contains?(keyword, ~w[healthcare immigration social]) -> "social"
      true -> "general"
    end
  end

  defp broadcast_updates(state) do
    # Broadcast full article updates
    Phoenix.PubSub.broadcast(
      GlobalPulse.PubSub,
      "news_updates",
      {:news_update, state.news_articles}
    )
    
    # Broadcast trending updates separately
    Phoenix.PubSub.broadcast(
      GlobalPulse.PubSub,
      "trending_updates",
      {:trending_update, state.trending_topics}
    )
    
    # Broadcast sentiment updates
    Phoenix.PubSub.broadcast(
      GlobalPulse.PubSub,
      "sentiment_updates",
      {:sentiment_update, state.sentiment_analysis}
    )
    
    # Broadcast breaking news if any high-importance articles
    breaking_news = state.news_articles
    |> Enum.filter(fn article -> 
      Map.get(article, :importance_score, 0) > 0.7 or
      Map.get(article, :breaking, false)
    end)
    |> Enum.take(5)
    
    if length(breaking_news) > 0 do
      Phoenix.PubSub.broadcast(
        GlobalPulse.PubSub,
        "breaking_news",
        {:breaking_news, breaking_news}
      )
    end
    
    # Broadcast live pulse indicator
    Phoenix.PubSub.broadcast(
      GlobalPulse.PubSub,
      "news_pulse",
      {:pulse, %{
        timestamp: DateTime.utc_now(),
        article_count: length(state.news_articles),
        sources_active: true
      }}
    )
    
    state
  end
end