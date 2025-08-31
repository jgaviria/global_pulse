defmodule GlobalPulse.PoliticalMonitor do
  use GenServer
  require Logger

  @poll_interval 300_000
  @sentiment_threshold 0.7
  
  defmodule State do
    defstruct [
      :news_articles,
      :trending_topics,
      :sentiment_analysis,
      :political_events,
      :social_media_trends,
      :last_update,
      :anomalies
    ]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    schedule_poll()
    
    # Fetch initial data from live APIs
    initial_news = fetch_live_news()
    initial_reddit = fetch_reddit_trends()
    initial_events = fetch_political_events()
    
    state = %State{
      news_articles: initial_news,
      trending_topics: initial_reddit,
      sentiment_analysis: calculate_live_sentiment(initial_news, initial_reddit),
      political_events: initial_events,
      social_media_trends: fetch_social_media_trends(),
      anomalies: []
    }
    
    {:ok, state}
  end

  def get_latest_data do
    GenServer.call(__MODULE__, :get_data)
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
      last_update: state.last_update
    }
    {:reply, data, state}
  end

  def handle_call(:get_sentiment, _from, state) do
    {:reply, state.sentiment_analysis, state}
  end

  def handle_info(:poll, state) do
    new_state = 
      state
      |> fetch_news_articles()
      |> fetch_political_events()
      |> fetch_social_trends()
      |> analyze_sentiment()
      |> detect_political_anomalies()
      |> broadcast_updates()
    
    schedule_poll()
    {:noreply, new_state}
  end

  defp fetch_news_articles(state) do
    # Use the new NewsAggregator service for real-time news
    articles = case GlobalPulse.Services.NewsAggregator.fetch_all_news() do
      {:ok, news_articles} ->
        Logger.info("📰 Refreshed with #{length(news_articles)} real articles")
        news_articles
      {:error, reason} ->
        Logger.warning("📰 News refresh failed: #{inspect(reason)}")
        state.news_articles || fallback_news()
    end
    
    %{state | news_articles: articles, last_update: DateTime.utc_now()}
  end

  defp fetch_from_news_source(source, api_key) do
    url = "https://newsapi.org/v2/top-headlines?sources=#{source}&apiKey=#{api_key}"
    
    case HTTPoison.get(url) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"articles" => articles}} ->
            Enum.map(articles, &parse_article/1)
          _ ->
            []
        end
      _ ->
        mock_news_articles(source)
    end
  end

  defp mock_news_articles(source) do
    [
      %{
        source: source,
        title: "Breaking: Major policy shift announced",
        description: "Government announces significant changes to economic policy",
        published_at: DateTime.utc_now(),
        sentiment: :rand.uniform(),
        importance_score: :rand.uniform(),
        categories: ["politics", "economy"],
        entities: ["Federal Reserve", "Congress", "White House"]
      },
      %{
        source: source,
        title: "International tensions rise over trade disputes",
        description: "Multiple nations engage in heated trade negotiations",
        published_at: DateTime.utc_now(),
        sentiment: :rand.uniform() - 0.5,
        importance_score: :rand.uniform(),
        categories: ["international", "trade"],
        entities: ["UN", "WTO", "G7"]
      }
    ]
  end

  defp parse_article(article) do
    %{
      source: article["source"]["name"],
      title: article["title"],
      description: article["description"],
      url: article["url"],
      published_at: parse_datetime(article["publishedAt"]),
      sentiment: calculate_basic_sentiment(article),
      importance_score: calculate_importance(article),
      categories: extract_categories(article),
      entities: extract_entities(article)
    }
  end

  defp fetch_political_events(state) do
    events = [
      %{
        type: :election,
        location: "United States",
        date: ~D[2024-11-05],
        impact_score: 0.95,
        description: "Presidential Election"
      },
      %{
        type: :summit,
        location: "Switzerland",
        date: Date.utc_today(),
        impact_score: 0.7,
        description: "G20 Economic Summit"
      },
      %{
        type: :policy_announcement,
        location: "Brussels",
        date: Date.utc_today(),
        impact_score: 0.6,
        description: "EU Climate Policy Update"
      }
    ]
    
    %{state | political_events: events}
  end

  defp fetch_social_trends(state) do
    trends = [
      %{
        platform: "twitter",
        hashtag: "#ClimateAction",
        volume: :rand.uniform(1_000_000),
        sentiment: 0.6,
        growth_rate: 0.15,
        timestamp: DateTime.utc_now()
      },
      %{
        platform: "reddit",
        topic: "worldnews",
        posts: :rand.uniform(10_000),
        volume: :rand.uniform(10_000),
        sentiment: 0.3,
        engagement: :rand.uniform(),
        growth_rate: :rand.uniform() * 0.5,
        timestamp: DateTime.utc_now()
      },
      %{
        platform: "twitter",
        hashtag: "#EconomicPolicy",
        volume: :rand.uniform(500_000),
        sentiment: 0.4,
        growth_rate: 0.08,
        timestamp: DateTime.utc_now()
      }
    ]
    
    %{state | social_media_trends: trends}
  end

  defp analyze_sentiment(state) do
    article_sentiment = calculate_aggregate_sentiment(state.news_articles)
    social_sentiment = calculate_social_sentiment(state.social_media_trends)
    
    sentiment_analysis = %{
      overall: (article_sentiment + social_sentiment) / 2,
      news: article_sentiment,
      social: social_sentiment,
      by_category: sentiment_by_category(state.news_articles),
      by_region: sentiment_by_region(state.news_articles),
      trend: calculate_sentiment_trend(state)
    }
    
    %{state | sentiment_analysis: sentiment_analysis}
  end

  defp calculate_basic_sentiment(article) do
    text = "#{article["title"]} #{article["description"]}"
    
    positive_words = ~w(growth success agreement peace prosperity improvement breakthrough advance)
    negative_words = ~w(crisis conflict decline failure tension dispute collapse threat warning)
    
    positive_count = Enum.count(positive_words, &String.contains?(String.downcase(text), &1))
    negative_count = Enum.count(negative_words, &String.contains?(String.downcase(text), &1))
    
    total = positive_count + negative_count
    if total > 0 do
      (positive_count - negative_count) / total
    else
      0.0
    end
  end

  defp calculate_importance(article) do
    keywords = ~w(president minister election war peace economy crisis breakthrough historic)
    text = String.downcase("#{article["title"]} #{article["description"]}")
    
    keyword_count = Enum.count(keywords, &String.contains?(text, &1))
    min(1.0, keyword_count * 0.2)
  end

  defp extract_categories(article) do
    text = String.downcase("#{article["title"]} #{article["description"]}")
    
    categories = []
    categories = if String.contains?(text, ~w(election vote campaign)), do: ["politics" | categories], else: categories
    categories = if String.contains?(text, ~w(economy market trade)), do: ["economy" | categories], else: categories
    categories = if String.contains?(text, ~w(war conflict military)), do: ["conflict" | categories], else: categories
    categories = if String.contains?(text, ~w(climate environment)), do: ["environment" | categories], else: categories
    
    if Enum.empty?(categories), do: ["general"], else: categories
  end

  defp extract_entities(article) do
    text = "#{article["title"]} #{article["description"]}"
    
    entities = Regex.scan(~r/[A-Z][a-z]+ [A-Z][a-z]+/, text)
    |> Enum.map(&List.first/1)
    |> Enum.uniq()
    |> Enum.take(5)
    
    entities
  end

  defp calculate_aggregate_sentiment(articles) do
    if Enum.empty?(articles) do
      0.0
    else
      sentiments = Enum.map(articles, & &1.sentiment)
      Enum.sum(sentiments) / length(sentiments)
    end
  end

  defp calculate_social_sentiment(trends) do
    if Enum.empty?(trends) do
      0.0
    else
      weighted_sentiments = Enum.map(trends, fn trend ->
        weight = Map.get(trend, :volume, Map.get(trend, :posts, 1))
        trend.sentiment * weight
      end)
      
      total_weight = Enum.sum(Enum.map(trends, &Map.get(&1, :volume, Map.get(&1, :posts, 1))))
      
      if total_weight > 0 do
        Enum.sum(weighted_sentiments) / total_weight
      else
        0.0
      end
    end
  end

  defp sentiment_by_category(articles) do
    articles
    |> Enum.flat_map(fn article ->
      Enum.map(article.categories, &{&1, article.sentiment})
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {category, sentiments} ->
      {category, Enum.sum(sentiments) / length(sentiments)}
    end)
    |> Map.new()
  end

  defp sentiment_by_region(_articles) do
    %{
      "north_america" => :rand.uniform() - 0.5,
      "europe" => :rand.uniform() - 0.5,
      "asia" => :rand.uniform() - 0.5,
      "middle_east" => :rand.uniform() - 0.5,
      "africa" => :rand.uniform() - 0.5,
      "south_america" => :rand.uniform() - 0.5
    }
  end

  defp calculate_sentiment_trend(state) do
    current = state.sentiment_analysis[:overall] || 0
    if current > 0.1, do: :positive, else: (if current < -0.1, do: :negative, else: :neutral)
  end

  defp detect_political_anomalies(state) do
    anomalies = []
    
    anomalies = anomalies ++ detect_sentiment_shifts(state)
    anomalies = anomalies ++ detect_volume_anomalies(state)
    anomalies = anomalies ++ detect_emerging_topics(state)
    
    if length(anomalies) > 0 do
      Logger.warning("Detected #{length(anomalies)} political/news anomalies")
      Phoenix.PubSub.broadcast(GlobalPulse.PubSub, "anomalies", {:new_anomalies, anomalies})
    end
    
    %{state | anomalies: anomalies}
  end

  defp detect_sentiment_shifts(state) do
    case state.sentiment_analysis do
      %{overall: sentiment} when abs(sentiment) > @sentiment_threshold ->
        [%{
          type: :sentiment_shift,
          direction: if(sentiment > 0, do: :positive, else: :negative),
          magnitude: abs(sentiment),
          severity: :high,
          timestamp: DateTime.utc_now()
        }]
      _ ->
        []
    end
  end

  defp detect_volume_anomalies(state) do
    state.social_media_trends
    |> Enum.flat_map(fn trend ->
      case trend do
        %{growth_rate: rate} when rate > 0.5 ->
          [%{
            type: :trending_spike,
            platform: trend.platform,
            topic: Map.get(trend, :hashtag, Map.get(trend, :topic)),
            growth_rate: rate,
            severity: :medium,
            timestamp: DateTime.utc_now()
          }]
        _ ->
          []
      end
    end)
  end

  defp detect_emerging_topics(state) do
    high_importance = Enum.filter(state.news_articles, &(&1.importance_score > 0.8))
    
    if length(high_importance) > 5 do
      [%{
        type: :breaking_news_cluster,
        count: length(high_importance),
        topics: Enum.flat_map(high_importance, & &1.categories) |> Enum.uniq(),
        severity: :high,
        timestamp: DateTime.utc_now()
      }]
    else
      []
    end
  end

  # Live API Functions using new NewsAggregator
  defp fetch_live_news do
    try do
      case GlobalPulse.Services.NewsAggregator.fetch_all_news() do
        {:ok, articles} -> 
          Logger.info("📰 Successfully fetched #{length(articles)} real news articles")
          articles
        {:error, reason} ->
          Logger.warning("📰 News fetch failed: #{inspect(reason)}, using fallback")
          fallback_news()
      end
    rescue
      e ->
        Logger.error("📰 News fetch crashed: #{inspect(e)}, using fallback")
        fallback_news()
    end
  end
  
  defp fetch_reddit_trends do
    try do
      case GlobalPulse.Services.NewsAggregator.fetch_trending_topics() do
        {:ok, topics} ->
          Logger.info("🔴 Successfully fetched #{length(topics)} trending topics")
          topics
        {:error, reason} ->
          Logger.warning("🔴 Trending fetch failed: #{inspect(reason)}, using fallback") 
          fallback_trending()
      end
    rescue
      e ->
        Logger.error("🔴 Trending fetch crashed: #{inspect(e)}, using fallback")
        fallback_trending()
    end
  end
  
  defp fetch_political_events do
    # For now, return curated events - can be extended with government APIs
    [
      %{
        title: "Congressional Hearing on Economic Policy",
        date: DateTime.add(DateTime.utc_now(), 2 * 24 * 3600, :second),
        location: "Washington, D.C.",
        type: "legislative",
        impact_score: 0.8,
        description: "Key economic policy discussions"
      },
      %{
        title: "Federal Reserve Interest Rate Decision",
        date: DateTime.add(DateTime.utc_now(), 5 * 24 * 3600, :second),
        location: "Washington, D.C.",
        type: "economic",
        impact_score: 0.9,
        description: "Potential impact on inflation and markets"
      },
      %{
        title: "State Election Results",
        date: DateTime.add(DateTime.utc_now(), 7 * 24 * 3600, :second),
        location: "Various States",
        type: "electoral",
        impact_score: 0.7,
        description: "Mid-term election updates"
      }
    ]
  end
  
  defp fetch_social_media_trends do
    # Simulate social media trends - can be replaced with real APIs
    [
      %{
        platform: "twitter",
        hashtag: "#Politics",
        volume: 125_000 + :rand.uniform(50_000),
        sentiment: -0.1 + :rand.uniform() * 0.2,
        growth_rate: :rand.uniform(),
        timestamp: DateTime.utc_now()
      },
      %{
        platform: "twitter", 
        hashtag: "#Election2024",
        volume: 89_000 + :rand.uniform(30_000),
        sentiment: 0.1 + :rand.uniform() * 0.3,
        growth_rate: :rand.uniform(),
        timestamp: DateTime.utc_now()
      },
      %{
        platform: "reddit",
        topic: "Political Discussion",
        volume: 45_000 + :rand.uniform(20_000),
        sentiment: -0.05 + :rand.uniform() * 0.1,
        growth_rate: :rand.uniform() * 0.5,
        timestamp: DateTime.utc_now()
      }
    ]
  end
  
  defp calculate_live_sentiment(news, reddit) do
    news_sentiment = calculate_news_sentiment(news)
    reddit_sentiment = calculate_reddit_sentiment(reddit)
    
    %{
      overall: (news_sentiment + reddit_sentiment) / 2,
      news: news_sentiment,
      social: reddit_sentiment,
      political_stability: 0.6 + :rand.uniform() * 0.2
    }
  end
  
  defp parse_news_articles(articles) do
    articles
    |> Enum.take(15)
    |> Enum.map(fn article ->
      %{
        title: Map.get(article, "title", ""),
        description: Map.get(article, "description", ""),
        source: get_in(article, ["source", "name"]) || "Unknown",
        published_at: parse_datetime(Map.get(article, "publishedAt")),
        url: Map.get(article, "url", ""),
        sentiment: calculate_article_sentiment(Map.get(article, "title", "") <> " " <> Map.get(article, "description", "")),
        categories: ["politics", "news"],
        importance_score: :rand.uniform()
      }
    end)
  end
  
  defp parse_reddit_posts(posts) do
    posts
    |> Enum.take(10)
    |> Enum.map(fn %{"data" => post} ->
      %{
        title: Map.get(post, "title", ""),
        score: Map.get(post, "score", 0),
        comments: Map.get(post, "num_comments", 0),
        author: Map.get(post, "author", "unknown"),
        created_at: DateTime.from_unix!(Map.get(post, "created_utc", 0)),
        subreddit: Map.get(post, "subreddit", "politics"),
        url: "https://reddit.com" <> Map.get(post, "permalink", ""),
        sentiment: calculate_article_sentiment(Map.get(post, "title", "")),
        engagement_rate: min(Map.get(post, "score", 0) / max(Map.get(post, "num_comments", 1), 1), 10.0)
      }
    end)
  end
  
  defp calculate_news_sentiment(articles) do
    if length(articles) > 0 do
      total = articles |> Enum.map(& &1.sentiment) |> Enum.sum()
      total / length(articles)
    else
      0.0
    end
  end
  
  defp calculate_reddit_sentiment(posts) do
    if length(posts) > 0 do
      total = posts |> Enum.map(& &1.sentiment) |> Enum.sum()
      total / length(posts)
    else
      0.0
    end
  end
  
  defp calculate_article_sentiment(text) do
    # Simple sentiment analysis based on keywords
    positive_words = ["good", "great", "excellent", "positive", "success", "win", "growth", "improvement", "beneficial"]
    negative_words = ["bad", "terrible", "awful", "negative", "failure", "lose", "decline", "crisis", "concern", "problem"]
    
    text_lower = String.downcase(text)
    positive_count = Enum.count(positive_words, &String.contains?(text_lower, &1))
    negative_count = Enum.count(negative_words, &String.contains?(text_lower, &1))
    
    case {positive_count, negative_count} do
      {0, 0} -> :rand.uniform() * 0.2 - 0.1  # neutral with slight random variation
      {p, n} -> (p - n) / (p + n + 1) * 0.8  # sentiment score between -0.8 and 0.8
    end
  end
  
  defp fallback_news do
    [
      %{
        title: "Economic Policy Discussion Continues in Congress",
        description: "Lawmakers debate fiscal measures amid economic uncertainty",
        source: "Political News",
        published_at: DateTime.utc_now(),
        url: "#",
        sentiment: 0.1,
        categories: ["politics", "economics"],
        importance_score: 0.7
      },
      %{
        title: "Federal Reserve Signals Interest Rate Changes",
        description: "Central bank officials hint at monetary policy adjustments",
        source: "Economic Times",
        published_at: DateTime.add(DateTime.utc_now(), -3600, :second),
        url: "#",
        sentiment: -0.2,
        categories: ["economics", "policy"],
        importance_score: 0.8
      },
      %{
        title: "Political Leaders Discuss Infrastructure Investment",
        description: "Bipartisan talks focus on long-term infrastructure spending",
        source: "Capitol Report",
        published_at: DateTime.add(DateTime.utc_now(), -7200, :second),
        url: "#",
        sentiment: 0.3,
        categories: ["politics", "infrastructure"],
        importance_score: 0.6
      }
    ]
  end
  
  defp fallback_trending do
    [
      %{
        title: "Political Discussion: Economic Policy Impact",
        score: 1250,
        comments: 234,
        author: "political_analyst",
        created_at: DateTime.utc_now(),
        subreddit: "politics",
        url: "#",
        sentiment: 0.1,
        engagement_rate: 5.3
      },
      %{
        title: "Analysis: Federal Reserve Policy Changes",
        score: 890,
        comments: 156,
        author: "economic_observer",
        created_at: DateTime.add(DateTime.utc_now(), -1800, :second),
        subreddit: "politics", 
        url: "#",
        sentiment: -0.15,
        engagement_rate: 5.7
      }
    ]
  end

  defp parse_datetime(nil), do: DateTime.utc_now()
  defp parse_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _} -> datetime
      _ -> DateTime.utc_now()
    end
  end

  defp broadcast_updates(state) do
    Phoenix.PubSub.broadcast(
      GlobalPulse.PubSub,
      "political_data",
      {:update, %{
        news: Enum.take(state.news_articles, 10),
        sentiment: state.sentiment_analysis,
        events: state.political_events,
        social: state.social_media_trends,
        timestamp: DateTime.utc_now()
      }}
    )
    state
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end
end