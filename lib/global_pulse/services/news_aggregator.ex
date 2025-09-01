defmodule GlobalPulse.Services.NewsAggregator do
  @moduledoc """
  Real-time news aggregator that pulls from multiple free and reliable news sources.
  Focuses on global pulse and unrest detection without requiring API keys.
  """
  require Logger

  # ============================================================================
  # RSS FEEDS CONFIGURATION
  # ============================================================================
  # RSS Feeds:
  #   - BBC World News (bbc_world, bbc_politics, bbc_business)
  #   - Reuters International (reuters_world, reuters_politics) 
  #   - Associated Press (ap_news)
  #   - The Guardian World (guardian_world, guardian_politics)
  #   - NPR News (npr_news, npr_politics)
  #   - CNN World (cnn_world, cnn_politics)
  #   - Al Jazeera (aljazeera)
  # ============================================================================
  @news_sources %{
    # BBC World News - Primary international source
    bbc_world: "https://feeds.bbci.co.uk/news/world/rss.xml",
    bbc_politics: "https://feeds.bbci.co.uk/news/politics/rss.xml", 
    bbc_business: "https://feeds.bbci.co.uk/news/business/rss.xml",
    
    # Reuters International - Business and world affairs
    reuters_world: "https://www.reuters.com/news/world",
    reuters_politics: "https://www.reuters.com/news/us", 
    
    # NPR News - US public radio with quality journalism  
    npr_news: "https://feeds.npr.org/1001/rss.xml",
    npr_politics: "https://feeds.npr.org/1014/rss.xml",
    
    # CNN World - Major US cable news network
    cnn_world: "http://rss.cnn.com/rss/edition.rss",
    cnn_politics: "http://rss.cnn.com/rss/cnn_allpolitics.rss",
    
    # Al Jazeera - International perspective from Qatar
    aljazeera: "https://www.aljazeera.com/xml/rss/all.xml",
    
    # The Guardian World - UK newspaper with global coverage
    guardian_world: "https://www.theguardian.com/world/rss",
    guardian_politics: "https://www.theguardian.com/politics/rss",
    
    # Associated Press - Wire service news
    ap_news: "https://rsshub.app/ap/topics/apf-topnews"
  }

  # ============================================================================
  # SOCIAL SOURCES CONFIGURATION  
  # ============================================================================
  # Social Sources:
  #   - Reddit /r/worldnews (world_news)
  #   - Reddit /r/politics (politics)
  #   - Reddit /r/news (news) 
  #   - Reddit /r/geopolitics (geopolitics)
  # ============================================================================
  @reddit_sources %{
    # Reddit /r/worldnews - International news and events
    world_news: "https://www.reddit.com/r/worldnews.json",
    
    # Reddit /r/politics - US political discussions
    politics: "https://www.reddit.com/r/politics.json",
    
    # Reddit /r/news - General breaking news
    news: "https://www.reddit.com/r/news.json",
    
    # Reddit /r/geopolitics - International relations analysis
    geopolitics: "https://www.reddit.com/r/geopolitics.json"
  }

  def fetch_all_news do
    Logger.info("🌍 Fetching real-time news from #{map_size(@news_sources)} RSS sources + #{map_size(@reddit_sources)} social sources...")
    start_time = System.monotonic_time(:millisecond)
    
    # ========================================================================
    # FETCH RSS FEEDS IN PARALLEL
    # Sources: BBC, Reuters, AP, Guardian, NPR, CNN, Al Jazeera (13 feeds)
    # ========================================================================
    rss_tasks = @news_sources
    |> Enum.map(fn {source, url} ->
      Task.async(fn -> fetch_rss_news(source, url) end)
    end)
    
    # ========================================================================
    # FETCH SOCIAL SOURCES IN PARALLEL  
    # Sources: Reddit /r/worldnews, /r/politics, /r/news, /r/geopolitics
    # ========================================================================
    reddit_tasks = @reddit_sources
    |> Enum.map(fn {source, url} ->
      Task.async(fn -> fetch_reddit_news(source, url) end)
    end)
    
    # Collect all results
    all_tasks = rss_tasks ++ reddit_tasks
    results = Task.await_many(all_tasks, 15_000)
    
    # Process and combine results
    all_articles = results
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.flat_map(fn {:ok, articles} -> articles end)
    |> deduplicate_articles()
    |> add_importance_scores()
    |> add_global_pulse_metadata()
    |> Enum.sort_by(& &1.importance_score, :desc)
    |> Enum.take(50)  # Top 50 most important articles
    
    fetch_time = System.monotonic_time(:millisecond) - start_time
    Logger.info("✅ Successfully fetched #{length(all_articles)} articles in #{fetch_time}ms")
    log_news_summary(all_articles)
    
    {:ok, all_articles}
  end

  def fetch_trending_topics do
    Logger.info("📈 Fetching trending topics from social sources...")
    
    # ========================================================================
    # FETCH TRENDING TOPICS FROM REDDIT
    # Sources: /r/worldnews, /r/politics, /r/news, /r/geopolitics  
    # ========================================================================
    reddit_tasks = @reddit_sources
    |> Enum.map(fn {source, url} ->
      Task.async(fn -> fetch_reddit_trending(source, url) end)
    end)
    
    results = Task.await_many(reddit_tasks, 10_000)
    
    trending_topics = results
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.flat_map(fn {:ok, topics} -> topics end)
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.take(20)
    
    {:ok, trending_topics}
  end

  defp fetch_rss_news(source, url) do
    try do
      case HTTPoison.get(url, headers(), timeout: 12_000) do
        {:ok, %{status_code: 200, body: body}} ->
          articles = parse_rss_feed(body, source)
          Logger.debug("📰 #{source}: #{length(articles)} articles")
          {:ok, articles}
          
        {:ok, %{status_code: status}} ->
          Logger.warning("🚨 #{source} returned status #{status}")
          {:ok, []}
          
        {:error, reason} ->
          Logger.warning("💥 #{source} failed: #{inspect(reason)}")
          {:ok, []}
      end
    rescue
      e ->
        Logger.error("❌ #{source} crashed: #{inspect(e)}")
        {:ok, []}
    end
  end

  defp fetch_reddit_news(source, url) do
    try do
      case HTTPoison.get(url, reddit_headers(), timeout: 10_000) do
        {:ok, %{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"data" => %{"children" => posts}}} ->
              articles = parse_reddit_posts(posts, source)
              Logger.debug("🔴 #{source}: #{length(articles)} posts")
              {:ok, articles}
              
            {:error, _} ->
              Logger.warning("🔴 #{source}: Invalid JSON")
              {:ok, []}
          end
          
        {:ok, %{status_code: status}} ->
          Logger.warning("🚨 Reddit #{source} returned status #{status}")
          {:ok, []}
          
        {:error, reason} ->
          Logger.warning("💥 Reddit #{source} failed: #{inspect(reason)}")
          {:ok, []}
      end
    rescue
      e ->
        Logger.error("❌ Reddit #{source} crashed: #{inspect(e)}")
        {:ok, []}
    end
  end

  defp fetch_reddit_trending(source, url) do
    case fetch_reddit_news(source, url) do
      {:ok, posts} ->
        trending = posts
        |> Enum.map(fn post ->
          %{
            title: post.title,
            score: Map.get(post, :score, 0),
            comments: Map.get(post, :comments, 0),
            author: Map.get(post, :author, "unknown"),
            created_at: post.published_at,
            subreddit: source,
            url: post.url,
            sentiment: post.sentiment,
            engagement_rate: calculate_engagement_rate(post)
          }
        end)
        {:ok, trending}
        
      error -> error
    end
  end

  defp parse_rss_feed(xml_body, source) do
    try do
      case Floki.parse_document(xml_body) do
        {:ok, document} ->
          items = Floki.find(document, "item")
          
          items
          |> Enum.map(&parse_rss_article(&1, source))
          |> Enum.filter(&(&1.title != "" && &1.title != nil))
          
        {:error, _} ->
          Logger.warning("Failed to parse RSS from #{source}")
          []
      end
    rescue
      _ -> []
    end
  end

  defp parse_rss_article(item, source) do
    title = extract_rss_text(item, "title") |> clean_html()
    description = extract_rss_text(item, "description") |> clean_html()
    link = extract_rss_text(item, "link")
    pub_date = extract_rss_text(item, "pubDate")
    
    %{
      title: title,
      description: description,
      url: link,
      source: format_source_name(source),
      published_at: parse_pub_date(pub_date),
      sentiment: analyze_sentiment(title, description),
      categories: categorize_article(title, description),
      article_type: :rss_news,
      raw_source: source
    }
  end

  defp parse_reddit_posts(posts, source) do
    posts
    |> Enum.map(fn %{"data" => post} ->
      title = Map.get(post, "title", "")
      selftext = Map.get(post, "selftext", "")
      
      %{
        title: title,
        description: String.slice(selftext, 0, 200),
        url: "https://reddit.com" <> Map.get(post, "permalink", ""),
        source: "Reddit - #{format_source_name(source)}",
        published_at: safe_parse_reddit_timestamp(Map.get(post, "created_utc")),
        sentiment: analyze_sentiment(title, selftext),
        categories: categorize_article(title, selftext),
        score: Map.get(post, "score", 0),
        comments: Map.get(post, "num_comments", 0),
        author: Map.get(post, "author", "unknown"),
        subreddit: Map.get(post, "subreddit", source),
        article_type: :reddit_post,
        raw_source: source
      }
    end)
    |> Enum.filter(&(&1.title != "" && &1.title != nil))
  end

  defp extract_rss_text(item, tag) do
    case Floki.find(item, tag) do
      [element] -> Floki.text(element) |> String.trim()
      [] -> ""
      multiple -> multiple |> List.first() |> Floki.text() |> String.trim()
    end
  rescue
    _ -> ""
  end

  defp clean_html(text) do
    text
    |> String.replace(~r/<!\[CDATA\[(.*?)\]\]>/s, "\\1")  # Remove CDATA wrapper
    |> String.replace(~r/<[^>]*>/, "")  # Remove HTML tags
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&apos;", "'")
    |> String.trim()
  end

  defp format_source_name(source) do
    source
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp analyze_sentiment(title, description \\ "") do
    text = String.downcase("#{title} #{description}")
    
    # Enhanced sentiment analysis for global pulse detection
    positive_keywords = [
      "peace", "agreement", "resolution", "cooperation", "stability", "growth", 
      "success", "progress", "breakthrough", "improvement", "recovery", "unity"
    ]
    
    negative_keywords = [
      "war", "conflict", "crisis", "violence", "tension", "protest", "riot",
      "attack", "terrorism", "collapse", "decline", "failure", "threat", 
      "sanctions", "dispute", "unrest", "instability", "emergency", "chaos"
    ]
    
    neutral_keywords = [
      "meeting", "discussion", "announcement", "statement", "report", "study",
      "analysis", "review", "update", "news", "information", "data"
    ]
    
    positive_count = count_keywords(text, positive_keywords)
    negative_count = count_keywords(text, negative_keywords)
    neutral_count = count_keywords(text, neutral_keywords)
    
    total = positive_count + negative_count + neutral_count
    
    cond do
      total == 0 -> 0.0
      negative_count > positive_count -> -0.3 - (negative_count * 0.1)
      positive_count > negative_count -> 0.3 + (positive_count * 0.1)
      true -> 0.0
    end
    |> max(-1.0)
    |> min(1.0)
  end

  defp categorize_article(title, description \\ "") do
    text = String.downcase("#{title} #{description}")
    categories = []
    
    categories = if contains_any?(text, ["election", "vote", "campaign", "political"]), 
                   do: ["politics" | categories], else: categories
    categories = if contains_any?(text, ["economy", "market", "trade", "business"]), 
                   do: ["economy" | categories], else: categories
    categories = if contains_any?(text, ["war", "military", "conflict", "defense"]), 
                   do: ["conflict" | categories], else: categories
    categories = if contains_any?(text, ["climate", "environment", "energy"]), 
                   do: ["environment" | categories], else: categories
    categories = if contains_any?(text, ["health", "pandemic", "medical"]), 
                   do: ["health" | categories], else: categories
    categories = if contains_any?(text, ["technology", "cyber", "digital"]), 
                   do: ["technology" | categories], else: categories
    categories = if contains_any?(text, ["protest", "riot", "unrest", "demonstration"]), 
                   do: ["social_unrest" | categories], else: categories
    
    if Enum.empty?(categories), do: ["general"], else: Enum.uniq(categories)
  end

  defp deduplicate_articles(articles) do
    # Remove articles with very similar titles
    articles
    |> Enum.uniq_by(&normalize_title/1)
  end

  defp normalize_title(article) do
    article.title
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, "")
    |> String.slice(0, 50)
  end

  defp add_importance_scores(articles) do
    Enum.map(articles, fn article ->
      Map.put(article, :importance_score, calculate_importance_score(article))
    end)
  end

  defp calculate_importance_score(article) do
    base_score = 0.5
    text = String.downcase("#{article.title} #{article.description}")
    
    # High importance keywords for global pulse
    high_impact_keywords = [
      "breaking", "urgent", "major", "significant", "crisis", "emergency",
      "war", "conflict", "attack", "terrorism", "coup", "revolution",
      "president", "prime minister", "government", "parliament", "congress"
    ]
    
    medium_impact_keywords = [
      "protest", "strike", "election", "policy", "economic", "military",
      "international", "global", "national", "security", "trade"
    ]
    
    # Score based on keywords
    high_count = count_keywords(text, high_impact_keywords)
    medium_count = count_keywords(text, medium_impact_keywords)
    
    keyword_score = (high_count * 0.3) + (medium_count * 0.15)
    
    # Boost score for certain categories
    category_boost = cond do
      "conflict" in article.categories -> 0.2
      "social_unrest" in article.categories -> 0.15
      "politics" in article.categories -> 0.1
      true -> 0.0
    end
    
    # Boost for negative sentiment (often indicates important events)
    sentiment_boost = if article.sentiment < -0.3, do: 0.1, else: 0.0
    
    # Reddit-specific boosts
    reddit_boost = case article.article_type do
      :reddit_post ->
        score = Map.get(article, :score, 0)
        comments = Map.get(article, :comments, 0)
        if score > 1000 || comments > 100, do: 0.1, else: 0.0
      _ -> 0.0
    end
    
    total_score = base_score + keyword_score + category_boost + sentiment_boost + reddit_boost
    min(1.0, max(0.0, total_score))
  end

  defp add_global_pulse_metadata(articles) do
    Enum.map(articles, fn article ->
      article
      |> Map.put(:threat_level, calculate_threat_level(article))
      |> Map.put(:geographic_scope, detect_geographic_scope(article))
      |> Map.put(:urgency, detect_urgency(article))
    end)
  end

  defp calculate_threat_level(article) do
    text = String.downcase("#{article.title} #{article.description}")
    
    threat_keywords = [
      "war", "attack", "terrorism", "violence", "bombing", "shooting",
      "crisis", "emergency", "threat", "danger", "conflict", "riot"
    ]
    
    threat_count = count_keywords(text, threat_keywords)
    
    base_threat = cond do
      "conflict" in article.categories -> 70
      "social_unrest" in article.categories -> 60
      "politics" in article.categories -> 30
      true -> 20
    end
    
    threat_score = base_threat + (threat_count * 15)
    min(100, max(0, threat_score))
  end

  defp safe_parse_reddit_timestamp(nil), do: DateTime.utc_now()
  defp safe_parse_reddit_timestamp(timestamp) when is_number(timestamp) do
    try do
      DateTime.from_unix!(timestamp)
    rescue
      _ -> DateTime.utc_now()
    end
  end
  defp safe_parse_reddit_timestamp(_), do: DateTime.utc_now()

  defp detect_geographic_scope(article) do
    text = String.downcase("#{article.title} #{article.description}")
    
    cond do
      contains_any?(text, ["global", "worldwide", "international", "multiple countries"]) -> :global
      contains_any?(text, ["europe", "asia", "africa", "americas", "middle east"]) -> :regional
      contains_any?(text, ["united states", "china", "russia", "india", "brazil", "uk"]) -> :national
      true -> :local
    end
  end

  defp detect_urgency(article) do
    text = String.downcase("#{article.title} #{article.description}")
    pub_time = article.published_at
    
    # Time-based urgency
    hours_ago = if pub_time, do: DateTime.diff(DateTime.utc_now(), pub_time, :hour), else: 24
    
    time_urgency = cond do
      hours_ago <= 1 -> :immediate
      hours_ago <= 6 -> :high
      hours_ago <= 24 -> :medium
      true -> :low
    end
    
    # Keyword-based urgency
    keyword_urgency = cond do
      contains_any?(text, ["breaking", "urgent", "alert", "developing"]) -> :immediate
      contains_any?(text, ["crisis", "emergency", "major"]) -> :high
      contains_any?(text, ["significant", "important"]) -> :medium
      true -> :normal
    end
    
    # Return highest urgency
    max_urgency([time_urgency, keyword_urgency])
  end

  # Helper functions
  defp count_keywords(text, keywords) do
    Enum.count(keywords, &String.contains?(text, &1))
  end

  defp contains_any?(text, keywords) do
    Enum.any?(keywords, &String.contains?(text, &1))
  end

  defp calculate_engagement_rate(post) do
    score = Map.get(post, :score, 0)
    comments = Map.get(post, :comments, 0)
    if comments > 0, do: score / comments, else: 0
  end

  defp max_urgency(urgencies) do
    urgency_order = [:immediate, :high, :medium, :normal, :low]
    urgencies
    |> Enum.filter(&(&1 in urgency_order))
    |> Enum.min_by(&Enum.find_index(urgency_order, fn x -> x == &1 end), fn -> :normal end)
  end

  defp parse_pub_date(date_string) do
    cond do
      is_nil(date_string) or date_string == "" ->
        DateTime.utc_now()
        
      String.contains?(date_string, "GMT") ->
        case Timex.parse(date_string, "{RFC822}") do
          {:ok, datetime} -> datetime
          _ -> DateTime.utc_now()
        end
        
      true ->
        case DateTime.from_iso8601(date_string) do
          {:ok, datetime, _} -> datetime
          _ -> DateTime.utc_now()
        end
    end
  rescue
    _ -> DateTime.utc_now()
  end

  defp headers do
    [
      {"User-Agent", "GlobalPulse/1.0 (News Monitoring Service)"},
      {"Accept", "application/rss+xml, application/xml, text/xml, */*"}
    ]
  end

  defp reddit_headers do
    [
      {"User-Agent", "GlobalPulse/1.0 by /u/globalpulse_monitor"}
    ]
  end

  defp log_news_summary(articles) do
    Logger.info("📊 News Summary:")
    Logger.info("  Total articles: #{length(articles)}")
    
    # Category breakdown
    categories = articles
    |> Enum.flat_map(& &1.categories)
    |> Enum.frequencies()
    Logger.info("  Categories: #{inspect(categories)}")
    
    # Source breakdown
    sources = articles
    |> Enum.map(& &1.source)
    |> Enum.frequencies()
    |> Enum.take(5)
    Logger.info("  Top sources: #{inspect(sources)}")
    
    # High importance articles
    high_importance = Enum.filter(articles, &(&1.importance_score > 0.7))
    if length(high_importance) > 0 do
      Logger.info("🚨 #{length(high_importance)} high-importance articles detected:")
      high_importance
      |> Enum.take(3)
      |> Enum.each(fn article ->
        Logger.info("  📰 [#{article.importance_score}] #{article.title} - #{article.source}")
      end)
    end
    
    # Threat level summary
    high_threat = Enum.filter(articles, &(&1.threat_level >= 70))
    if length(high_threat) > 0 do
      Logger.warning("⚠️  #{length(high_threat)} high-threat articles detected")
    end
  end
end