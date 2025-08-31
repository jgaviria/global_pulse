defmodule GlobalPulse.Services.LiveNewsFeed do
  @moduledoc """
  Simplified live news feed service for real-time dashboard updates.
  Focuses on speed and simplicity for the news feed component.
  """
  require Logger

  # ============================================================================
  # LIVE NEWS FEED SOURCES (OPTIMIZED FOR SPEED)
  # ============================================================================
  # RSS Feeds Used:
  #   - Reuters International (reuters)
  #   - BBC World News (bbc)
  #   - Associated Press (ap)
  #   - The Guardian World (guardian)  
  #   - NPR News (npr)
  # ============================================================================
  @quick_sources %{
    # Reuters International - Fast updating wire service
    reuters: "https://www.reuters.com/news/world",
    
    # BBC World News - Reliable international coverage
    bbc: "https://feeds.bbci.co.uk/news/world/rss.xml",
    
    # Associated Press - Breaking news wire
    ap: "https://rsshub.app/ap/topics/apf-topnews",
    
    # The Guardian World - UK perspective on global events
    guardian: "https://www.theguardian.com/world/rss",
    
    # NPR News - Quality US public radio journalism
    npr: "https://feeds.npr.org/1001/rss.xml"
  }

  def fetch_live_news_feed(limit \\ 20) do
    Logger.info("📡 Fetching live news feed...")
    start_time = System.monotonic_time(:millisecond)
    
    # Fetch from a subset of sources for speed
    tasks = @quick_sources
    |> Enum.take(3)  # Only use 3 fastest sources
    |> Enum.map(fn {source, url} ->
      Task.async(fn -> fetch_source_quickly(source, url) end)
    end)
    
    # Collect results with shorter timeout for real-time performance
    results = Task.await_many(tasks, 8_000)
    
    articles = results
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.flat_map(fn {:ok, articles} -> articles end)
    |> Enum.uniq_by(&normalize_title/1)
    |> Enum.sort_by(& &1.published_at, {:desc, DateTime})
    |> Enum.take(limit)
    |> add_quick_metadata()
    
    fetch_time = System.monotonic_time(:millisecond) - start_time
    Logger.info("⚡ Live news feed ready: #{length(articles)} articles in #{fetch_time}ms")
    
    {:ok, articles}
  end

  def fetch_breaking_news do
    Logger.info("🚨 Checking for breaking news...")
    
    # Check sources that typically have breaking news
    breaking_sources = [
      {"bbc", "https://feeds.bbci.co.uk/news/rss.xml"},
      {"reuters", "https://www.reuters.com/news/world"},
      {"cnn", "http://rss.cnn.com/rss/edition.rss"}
    ]
    
    tasks = breaking_sources
    |> Enum.map(fn {source, url} ->
      Task.async(fn -> fetch_breaking_from_source(source, url) end)
    end)
    
    results = Task.await_many(tasks, 6_000)
    
    breaking_articles = results
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.flat_map(fn {:ok, articles} -> articles end)
    |> Enum.filter(&is_breaking_news?/1)
    |> Enum.sort_by(& &1.urgency_score, :desc)
    |> Enum.take(5)
    
    if length(breaking_articles) > 0 do
      Logger.warning("🚨 #{length(breaking_articles)} breaking news items found!")
    end
    
    {:ok, breaking_articles}
  end

  defp fetch_source_quickly(source, url) do
    try do
      case HTTPoison.get(url, quick_headers(), timeout: 6_000, recv_timeout: 6_000) do
        {:ok, %{status_code: 200, body: body}} ->
          articles = parse_rss_quickly(body, source)
          {:ok, articles}
          
        {:ok, %{status_code: status}} ->
          Logger.debug("⚠️  #{source} returned #{status}")
          {:ok, []}
          
        {:error, _reason} ->
          {:ok, []}
      end
    rescue
      _ -> {:ok, []}
    end
  end

  defp fetch_breaking_from_source(source, url) do
    case fetch_source_quickly(source, url) do
      {:ok, articles} ->
        # Filter for recent articles that might be breaking news
        recent_articles = articles
        |> Enum.filter(fn article ->
          hours_ago = DateTime.diff(DateTime.utc_now(), article.published_at, :hour)
          hours_ago <= 2  # Only articles from last 2 hours
        end)
        {:ok, recent_articles}
        
      error -> error
    end
  end

  defp parse_rss_quickly(xml_body, source) do
    try do
      case Floki.parse_document(xml_body) do
        {:ok, document} ->
          Floki.find(document, "item")
          |> Enum.take(10)  # Only take first 10 for speed
          |> Enum.map(&parse_article_quickly(&1, source))
          |> Enum.filter(&(&1.title != ""))
          
        {:error, _} -> []
      end
    rescue
      _ -> []
    end
  end

  defp parse_article_quickly(item, source) do
    title = extract_text_quickly(item, "title")
    description = extract_text_quickly(item, "description") |> clean_text()
    link = extract_text_quickly(item, "link")
    pub_date = extract_text_quickly(item, "pubDate")
    
    %{
      title: title,
      description: String.slice(description, 0, 150),  # Truncate for performance
      url: link,
      source: format_source(source),
      published_at: parse_date_quickly(pub_date),
      sentiment: quick_sentiment(title),
      category: quick_categorize(title)
    }
  end

  defp extract_text_quickly(item, tag) do
    case Floki.find(item, tag) do
      [element] -> Floki.text(element) |> String.trim()
      [] -> ""
      [first | _] -> Floki.text(first) |> String.trim()
    end
  rescue
    _ -> ""
  end

  defp clean_text(text) when is_binary(text) do
    text
    |> String.replace(~r/<[^>]*>/, "")
    |> String.replace(~r/&\w+;/, "")
    |> String.trim()
  end
  defp clean_text(_), do: ""

  defp format_source(source) when is_atom(source) do
    case source do
      :bbc -> "BBC News"
      :reuters -> "Reuters"
      :ap -> "Associated Press" 
      :guardian -> "The Guardian"
      :npr -> "NPR"
      _ -> source |> Atom.to_string() |> String.capitalize()
    end
  end

  defp parse_date_quickly(date_string) do
    cond do
      is_nil(date_string) or date_string == "" ->
        DateTime.utc_now()
        
      String.contains?(date_string, "GMT") ->
        case Timex.parse(date_string, "{RFC822}") do
          {:ok, datetime} -> datetime
          _ -> DateTime.utc_now()
        end
        
      true ->
        DateTime.utc_now()  # Fallback to now for speed
    end
  rescue
    _ -> DateTime.utc_now()
  end

  defp quick_sentiment(title) do
    text = String.downcase(title)
    
    negative_words = ["crisis", "attack", "war", "death", "violence", "conflict", "threat"]
    positive_words = ["peace", "agreement", "success", "growth", "progress", "cooperation"]
    
    negative_count = count_words(text, negative_words)
    positive_count = count_words(text, positive_words)
    
    cond do
      negative_count > positive_count -> -0.5
      positive_count > negative_count -> 0.5
      true -> 0.0
    end
  end

  defp quick_categorize(title) do
    text = String.downcase(title)
    
    cond do
      String.contains?(text, ["politic", "election", "government"]) -> "politics"
      String.contains?(text, ["econom", "market", "trade"]) -> "economy"
      String.contains?(text, ["war", "conflict", "military"]) -> "conflict"
      String.contains?(text, ["health", "medical", "pandemic"]) -> "health"
      String.contains?(text, ["climate", "environment"]) -> "environment"
      true -> "general"
    end
  end

  defp count_words(text, words) do
    Enum.count(words, &String.contains?(text, &1))
  end

  defp normalize_title(article) do
    article.title
    |> String.downcase()
    |> String.slice(0, 30)
  end

  defp add_quick_metadata(articles) do
    Enum.map(articles, fn article ->
      article
      |> Map.put(:importance_score, calculate_quick_importance(article))
      |> Map.put(:time_ago, calculate_time_ago(article.published_at))
    end)
  end

  defp calculate_quick_importance(article) do
    text = String.downcase(article.title)
    
    importance_words = ["breaking", "urgent", "major", "significant", "crisis", "president"]
    word_count = count_words(text, importance_words)
    
    base_score = 0.5
    word_score = min(0.4, word_count * 0.1)
    sentiment_score = if article.sentiment < -0.3, do: 0.1, else: 0.0
    
    base_score + word_score + sentiment_score
  end

  defp calculate_time_ago(published_at) do
    diff_seconds = DateTime.diff(DateTime.utc_now(), published_at, :second)
    
    cond do
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> "#{div(diff_seconds, 86400)}d ago"
    end
  end

  defp is_breaking_news?(article) do
    text = String.downcase(article.title)
    hours_ago = DateTime.diff(DateTime.utc_now(), article.published_at, :hour)
    
    # Breaking news indicators
    has_breaking_keywords = String.contains?(text, ["breaking", "urgent", "alert", "developing"])
    is_recent = hours_ago <= 1
    has_high_importance = article.importance_score > 0.8
    
    has_breaking_keywords || (is_recent && has_high_importance)
  end

  defp quick_headers do
    [
      {"User-Agent", "GlobalPulse/1.0 Live Feed"},
      {"Accept", "application/rss+xml, text/xml, */*"},
      {"Connection", "close"}
    ]
  end
end