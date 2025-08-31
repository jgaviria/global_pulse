defmodule GlobalPulse.Services.GoogleTrendsRSS do
  @moduledoc """
  Service for fetching Google Trends data via official RSS feeds.
  More reliable than unofficial API scraping.
  """
  require Logger

  # Multiple RSS feeds to detect global unrest and social tensions
  @trend_feeds %{
    # Political instability indicators
    political_unrest: "https://news.google.com/rss/search?q=protest+OR+riot+OR+uprising+OR+coup+OR+revolution+OR+civil+unrest&hl=en-US&gl=US&ceid=US:en",
    
    # Government and institutional stress
    government_crisis: "https://news.google.com/rss/search?q=government+crisis+OR+political+crisis+OR+martial+law+OR+emergency+powers&hl=en-US&gl=US&ceid=US:en",
    
    # Economic instability (major unrest trigger)
    economic_crisis: "https://news.google.com/rss/search?q=economic+crisis+OR+recession+OR+inflation+surge+OR+unemployment+OR+bank+run&hl=en-US&gl=US&ceid=US:en",
    
    # Social tensions and conflicts
    social_tensions: "https://news.google.com/rss/search?q=social+unrest+OR+racial+tension+OR+ethnic+conflict+OR+strike+OR+labor+dispute&hl=en-US&gl=US&ceid=US:en",
    
    # International conflicts and tensions
    international_conflict: "https://news.google.com/rss/search?q=military+conflict+OR+border+dispute+OR+sanctions+OR+diplomatic+crisis+OR+trade+war&hl=en-US&gl=US&ceid=US:en",
    
    # Cyber warfare and information warfare
    cyber_threats: "https://news.google.com/rss/search?q=cyber+attack+OR+hacking+OR+data+breach+OR+election+interference+OR+disinformation&hl=en-US&gl=US&ceid=US:en",
    
    # Natural disasters (often trigger secondary unrest)
    disaster_response: "https://news.google.com/rss/search?q=natural+disaster+OR+hurricane+OR+earthquake+OR+flood+OR+emergency+response&hl=en-US&gl=US&ceid=US:en",
    
    # Supply chain and infrastructure stress
    infrastructure_stress: "https://news.google.com/rss/search?q=supply+chain+OR+power+outage+OR+infrastructure+failure+OR+food+shortage&hl=en-US&gl=US&ceid=US:en",
    
    # Migration and refugee crises (unrest indicators)
    migration_crisis: "https://news.google.com/rss/search?q=refugee+crisis+OR+migration+OR+border+crisis+OR+displacement&hl=en-US&gl=US&ceid=US:en",
    
    # General breaking news for rapid response
    breaking_alerts: "https://news.google.com/rss/search?q=breaking+news+OR+urgent+OR+developing+story+OR+alert&hl=en-US&gl=US&ceid=US:en"
  }

  @political_keywords [
    "congress", "senate", "house", "biden", "trump", "election", 
    "politics", "government", "policy", "legislation", "voting",
    "inflation", "economy", "immigration", "healthcare", "supreme court",
    "republican", "democrat", "campaign", "poll"
  ]

  def fetch_daily_trends do
    fetch_all_trend_categories()
  end

  def fetch_realtime_trends do
    fetch_all_trend_categories()
  end

  def fetch_all_trend_categories do
    start_time = System.monotonic_time(:millisecond)
    Logger.info("🔍 Starting Google Trends data pull from #{map_size(@trend_feeds)} category feeds...")
    Logger.info("📋 Categories: #{@trend_feeds |> Map.keys() |> Enum.join(", ")}")
    
    # Fetch from all feeds in parallel
    tasks = @trend_feeds
    |> Enum.map(fn {category, url} ->
      Task.async(fn -> fetch_category_feed(category, url) end)
    end)
    
    # Collect results with timeout
    raw_results = tasks |> Task.await_many(20_000)  # 20 second timeout for all requests
    
    # Log raw results summary
    Logger.info("📊 Raw fetch results:")
    raw_results
    |> Enum.with_index()
    |> Enum.each(fn {result, index} ->
      category = @trend_feeds |> Map.keys() |> Enum.at(index)
      case result do
        {:ok, trends} -> 
          Logger.info("  ✅ #{category}: #{length(trends)} items fetched")
        {:error, reason} ->
          Logger.warning("  ❌ #{category}: Failed - #{inspect(reason)}")
      end
    end)
    
    # Process and filter results
    processed_trends = raw_results
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.flat_map(fn {:ok, trends} -> trends end)
    |> log_raw_trend_data()  # Log the raw data
    |> Enum.uniq_by(& &1.title)
    |> Enum.sort_by(& &1.threat_level, :desc)  # Sort by threat level for unrest detection
    |> Enum.take(20)  # Top 20 most significant items
    
    fetch_duration = System.monotonic_time(:millisecond) - start_time
    Logger.info("⏱️  Total fetch time: #{fetch_duration}ms")
    
    case processed_trends do
      [] -> 
        Logger.warning("⚠️  No trend data retrieved from any source")
        {:error, :no_data}
      trends -> 
        Logger.info("✅ Successfully processed #{length(trends)} high-priority trends")
        log_final_trends_summary(trends)
        {:ok, trends}
    end
  end

  defp fetch_category_feed(category, url) do
    fetch_start = System.monotonic_time(:millisecond)
    Logger.debug("🌐 Fetching #{category} from: #{String.slice(url, 0, 80)}...")
    
    case HTTPoison.get(url, headers(), timeout: 15_000) do
      {:ok, %{status_code: 200, body: body}} ->
        fetch_time = System.monotonic_time(:millisecond) - fetch_start
        Logger.debug("📥 #{category} HTTP fetch: #{fetch_time}ms, body size: #{byte_size(body)} bytes")
        
        # Log a sample of the raw XML for debugging
        body_sample = String.slice(body, 0, 200)
        Logger.debug("📄 #{category} XML sample: #{body_sample}...")
        
        case parse_rss_feed(body, category) do
          {:ok, trends} -> 
            Logger.debug("✅ #{category} parsed successfully: #{length(trends)} items")
            {:ok, trends}
          {:error, reason} -> 
            Logger.warning("❌ #{category} parse failed: #{inspect(reason)}")
            {:ok, []}  # Don't fail entire batch for one category
        end
        
      {:ok, %{status_code: status}} ->
        fetch_time = System.monotonic_time(:millisecond) - fetch_start
        Logger.warning("🚨 #{category} HTTP error #{status} after #{fetch_time}ms")
        {:ok, []}  # Return empty instead of error
        
      {:error, reason} ->
        fetch_time = System.monotonic_time(:millisecond) - fetch_start
        Logger.warning("💥 #{category} request failed after #{fetch_time}ms: #{inspect(reason)}")
        {:ok, []}  # Return empty instead of error
    end
  end

  defp headers do
    [
      {"User-Agent", "GlobalPulse/1.0 (Political Monitoring Service)"},
      {"Accept", "application/rss+xml, application/xml, text/xml"},
      {"Accept-Language", "en-US,en;q=0.9"}
    ]
  end

  defp parse_rss_feed(xml_body, category) do
    try do
      # Use Floki which handles encoding issues better than xmerl
      case Floki.parse_document(xml_body) do
        {:ok, document} ->
          # Extract all item elements
          items = Floki.find(document, "item")
          Logger.debug("📄 Extracted #{length(items)} RSS items from #{category}")
          
          trends = items
          |> Enum.map(&parse_floki_item(&1, category))
          |> Enum.filter(&is_unrest_related_trend?/1)
          |> Enum.take(15)
          |> add_trend_metadata()

          Logger.debug("✅ #{category}: Processed #{length(trends)} relevant trends")
          {:ok, trends}
          
        {:error, reason} ->
          Logger.error("Failed to parse #{category} RSS with Floki: #{inspect(reason)}")
          {:error, :parse_error}
      end
    rescue
      e ->
        Logger.error("Failed to parse #{category} RSS: #{inspect(e)}")
        Logger.error("XML sample: #{String.slice(xml_body, 0, 500)}")
        {:error, :parse_error}
    end
  end

  # Parse RSS item using Floki instead of xmerl
  defp parse_floki_item(item, category) do
    title = extract_floki_text(item, "title") |> clean_title()
    description = extract_floki_text(item, "description")
    pub_date = extract_floki_text(item, "pubDate")
    source_url = extract_floki_text(item, "link")
    
    # Extract source from description HTML
    source = extract_source_from_floki_description(description)
    
    %{
      title: title,
      description: description,
      published_at: parse_pub_date(pub_date),
      traffic: "N/A",
      search_volume: estimate_search_volume(title),
      category: category,
      subcategory: classify_subcategory(title, category),
      sentiment_indicator: analyze_title_sentiment(title),
      threat_level: calculate_threat_level(title, category),
      urgency: calculate_urgency(title, pub_date),
      geographic_scope: detect_geographic_scope(title),
      source: source,
      source_url: source_url,
      timestamp: DateTime.utc_now()
    }
  end

  # Keep old function for backwards compatibility if needed
  defp parse_rss_item(item, category) do
    title = extract_text(item, :title)
    description = extract_text(item, :description) 
    pub_date = extract_text(item, :pubDate)
    
    # Extract traffic info from description if available
    traffic_info = extract_traffic_from_description(description)
    
    %{
      title: clean_title(title),
      description: description,
      published_at: parse_pub_date(pub_date),
      traffic: traffic_info[:traffic] || "N/A",
      search_volume: traffic_info[:search_volume] || estimate_search_volume(title),
      category: category,
      subcategory: classify_subcategory(title, category),
      sentiment_indicator: analyze_title_sentiment(title),
      threat_level: calculate_threat_level(title, category),
      urgency: calculate_urgency(title, pub_date),
      geographic_scope: detect_geographic_scope(title),
      source: extract_source_from_description(description),
      timestamp: DateTime.utc_now()
    }
  end

  defp clean_title(title) do
    title
    |> String.replace(~r/^\d+\.\s*/, "") # Remove numbering like "1. "
    |> String.trim()
  end

  defp extract_traffic_from_description(description) do
    # Google sometimes includes traffic info in description
    traffic = cond do
      String.contains?(description, "searches") ->
        case Regex.run(~r/(\d+[\+\,\s]*\d*)\s*searches/i, description) do
          [_, number] -> number
          _ -> nil
        end
      String.contains?(description, "trending") -> "High"
      true -> nil
    end
    
    %{traffic: traffic, search_volume: estimate_volume_from_traffic(traffic)}
  end

  defp estimate_volume_from_traffic(nil), do: "Unknown"
  defp estimate_volume_from_traffic(traffic) when is_binary(traffic) do
    cond do
      String.contains?(traffic, "+") -> "100K+"
      String.match?(traffic, ~r/\d{4,}/) -> "50K - 100K"
      true -> "10K - 50K"
    end
  end

  defp estimate_search_volume(title) do
    # Estimate based on title keywords and typical search patterns
    title_lower = String.downcase(title)
    
    high_volume_terms = ["election", "biden", "trump", "congress", "supreme court"]
    medium_volume_terms = ["senate", "house", "policy", "immigration"]
    
    cond do
      Enum.any?(high_volume_terms, &String.contains?(title_lower, &1)) -> "75K - 150K"
      Enum.any?(medium_volume_terms, &String.contains?(title_lower, &1)) -> "25K - 75K"
      true -> "10K - 25K"
    end
  end

  defp parse_pub_date(pub_date_str) do
    case Timex.parse(pub_date_str, "{RFC822}") do
      {:ok, datetime} -> datetime
      _ -> DateTime.utc_now()
    end
  end

  # Updated to be more inclusive of all unrest-related content
  defp is_unrest_related_trend?(%{title: title}) when is_binary(title) and title != "" do
    true  # Accept all trends since we're already filtering by category-specific RSS feeds
  end
  defp is_unrest_related_trend?(_), do: false  # Filter out empty or invalid items

  defp classify_political_category(title) do
    title_lower = String.downcase(title)
    
    cond do
      Enum.any?(["election", "vote", "campaign", "candidate"], &String.contains?(title_lower, &1)) -> 
        :election
      Enum.any?(["congress", "senate", "house", "legislation"], &String.contains?(title_lower, &1)) -> 
        :legislative
      Enum.any?(["biden", "trump", "president", "white house"], &String.contains?(title_lower, &1)) -> 
        :executive
      Enum.any?(["supreme court", "court", "justice", "legal"], &String.contains?(title_lower, &1)) -> 
        :judicial
      Enum.any?(["economy", "inflation", "jobs", "market"], &String.contains?(title_lower, &1)) -> 
        :economic_policy
      Enum.any?(["immigration", "border", "healthcare", "climate"], &String.contains?(title_lower, &1)) -> 
        :policy_issue
      true -> 
        :general_political
    end
  end

  defp analyze_title_sentiment(title) do
    title_lower = String.downcase(title)
    
    positive_keywords = [
      "wins", "victory", "success", "approval", "agreement", "progress", 
      "support", "positive", "up", "rise", "boost", "gain"
    ]
    
    negative_keywords = [
      "crisis", "scandal", "controversy", "concern", "problem", "decline", 
      "falls", "drops", "criticism", "opposition", "conflict", "tension"
    ]
    
    neutral_keywords = [
      "meeting", "discussion", "hearing", "announcement", "statement", 
      "address", "speech", "visit", "plan", "proposal"
    ]
    
    positive_count = Enum.count(positive_keywords, &String.contains?(title_lower, &1))
    negative_count = Enum.count(negative_keywords, &String.contains?(title_lower, &1))
    neutral_count = Enum.count(neutral_keywords, &String.contains?(title_lower, &1))
    
    cond do
      positive_count > 0 and positive_count >= negative_count -> :positive
      negative_count > 0 and negative_count > positive_count -> :negative
      neutral_count > 0 -> :neutral
      true -> :neutral
    end
  end

  defp add_trend_metadata(trends) do
    trends
    |> Enum.with_index()
    |> Enum.map(fn {trend, index} ->
      trend
      |> Map.put(:interest_score, calculate_interest_score(trend, index))
      |> Map.put(:change_24h, simulate_change_24h(trend))
      |> Map.put(:sentiment_shift, detect_sentiment_shift(trend))
      |> Map.put(:related_queries, generate_related_queries(trend.title))
    end)
  end

  defp calculate_interest_score(trend, index) do
    # Higher scores for newer trends and certain categories
    base_score = 100 - (index * 8) # Declining score based on position
    
    category_bonus = case trend.category do
      :election -> 20
      :executive -> 15  
      :legislative -> 10
      :judicial -> 12
      :economic_policy -> 8
      _ -> 0
    end
    
    sentiment_bonus = case trend.sentiment_indicator do
      :positive -> 5
      :negative -> 10  # Negative news often gets more attention
      :neutral -> 0
    end
    
    max(25, min(100, base_score + category_bonus + sentiment_bonus))
  end

  defp simulate_change_24h(trend) do
    # Simulate 24h change based on sentiment and category
    base_change = case trend.sentiment_indicator do
      :positive -> Enum.random(2..8) * 1.0
      :negative -> Enum.random(-8..-2) * 1.0  
      :neutral -> Enum.random(-3..3) * 1.0
    end
    
    category_multiplier = case trend.category do
      :election -> 1.5
      :executive -> 1.3
      :judicial -> 1.2
      _ -> 1.0
    end
    
    Float.round(base_change * category_multiplier, 1)
  end

  defp detect_sentiment_shift(trend) do
    change = trend[:change_24h] || 0
    interest = trend[:interest_score] || 50
    
    cond do
      change > 6 && interest > 75 -> :surge
      change < -6 && interest > 75 -> :crash
      abs(change) > 3 -> if change > 0, do: :rising, else: :falling
      true -> :stable
    end
  end

  defp generate_related_queries(title) do
    # Extract key terms and generate related queries
    title_words = title |> String.downcase() |> String.split() |> Enum.take(3)
    
    base_queries = title_words
    |> Enum.map(&("#{&1} news"))
    |> Enum.take(2)
    
    [title | base_queries]
    |> Enum.uniq()
    |> Enum.take(3)
  end

  # Threat level calculation for unrest detection (0-100)
  defp calculate_threat_level(title, category) do
    title_lower = String.downcase(title)
    base_threat = category_base_threat(category)
    
    # High-threat keywords add to the score
    high_threat_keywords = [
      "riot", "violence", "shooting", "explosion", "attack", "terrorism",
      "coup", "revolution", "martial law", "emergency", "crisis", "collapse",
      "war", "conflict", "invasion", "bombing", "assassination"
    ]
    
    medium_threat_keywords = [
      "protest", "unrest", "tension", "dispute", "strike", "evacuation",
      "lockdown", "curfew", "sanctions", "warning", "alert", "surge"
    ]
    
    high_threat_count = Enum.count(high_threat_keywords, &String.contains?(title_lower, &1))
    medium_threat_count = Enum.count(medium_threat_keywords, &String.contains?(title_lower, &1))
    
    threat_score = base_threat + (high_threat_count * 25) + (medium_threat_count * 10)
    
    min(100, max(0, threat_score))
  end

  defp category_base_threat(category) do
    case category do
      :political_unrest -> 70
      :government_crisis -> 65
      :international_conflict -> 60
      :cyber_threats -> 55
      :economic_crisis -> 50
      :social_tensions -> 45
      :disaster_response -> 40
      :migration_crisis -> 35
      :infrastructure_stress -> 30
      :breaking_alerts -> 25
      _ -> 20
    end
  end

  defp calculate_urgency(title, pub_date) do
    title_lower = String.downcase(title)
    
    # Time-based urgency
    time_urgency = case parse_pub_date(pub_date) do
      date when is_struct(date, DateTime) ->
        hours_ago = DateTime.diff(DateTime.utc_now(), date, :hour)
        cond do
          hours_ago <= 1 -> :immediate
          hours_ago <= 6 -> :urgent  
          hours_ago <= 24 -> :high
          hours_ago <= 72 -> :medium
          true -> :low
        end
      _ -> :unknown
    end
    
    # Keyword-based urgency
    keyword_urgency = cond do
      Enum.any?(["breaking", "urgent", "alert", "developing", "live"], 
                &String.contains?(title_lower, &1)) -> :immediate
      Enum.any?(["latest", "update", "now", "today"], 
                &String.contains?(title_lower, &1)) -> :high
      true -> :normal
    end
    
    # Return highest urgency level
    max_urgency([time_urgency, keyword_urgency])
  end

  defp max_urgency(urgencies) do
    urgency_order = [:immediate, :urgent, :high, :medium, :normal, :low, :unknown]
    urgencies
    |> Enum.filter(&(&1 in urgency_order))
    |> Enum.min_by(&Enum.find_index(urgency_order, fn x -> x == &1 end), fn -> :normal end)
  end

  defp detect_geographic_scope(title) do
    title_lower = String.downcase(title)
    
    cond do
      Enum.any?(["global", "worldwide", "international", "multiple countries"], 
                &String.contains?(title_lower, &1)) -> :global
      Enum.any?(["europe", "asia", "africa", "americas", "middle east"], 
                &String.contains?(title_lower, &1)) -> :regional
      Enum.any?(["united states", "china", "russia", "india", "brazil"], 
                &String.contains?(title_lower, &1)) -> :national
      Enum.any?(["city", "state", "province", "county"], 
                &String.contains?(title_lower, &1)) -> :local
      true -> :unknown
    end
  end

  defp classify_subcategory(title, category) do
    title_lower = String.downcase(title)
    
    case category do
      :political_unrest ->
        cond do
          String.contains?(title_lower, "protest") -> :protest
          String.contains?(title_lower, "riot") -> :riot
          String.contains?(title_lower, "coup") -> :coup
          true -> :general_unrest
        end
      :economic_crisis ->
        cond do
          String.contains?(title_lower, "inflation") -> :inflation
          String.contains?(title_lower, "recession") -> :recession
          String.contains?(title_lower, "unemployment") -> :unemployment
          true -> :general_economic
        end
      :international_conflict ->
        cond do
          String.contains?(title_lower, "military") -> :military
          String.contains?(title_lower, "diplomatic") -> :diplomatic
          String.contains?(title_lower, "trade") -> :trade_war
          true -> :general_conflict
        end
      _ -> :general
    end
  end

  defp extract_source_from_description(description) do
    # Try to extract source from Google News description format
    case Regex.run(~r/<font color="#6f6f6f">([^<]+)<\/font>/, description) do
      [_, source] -> String.trim(source)
      _ -> "Unknown Source"
    end
  end

  # Log raw trend data for debugging and monitoring
  defp log_raw_trend_data(trends) do
    Logger.info("📈 Raw trends data summary:")
    Logger.info("  Total items before deduplication: #{length(trends)}")
    
    # Log by category
    trends
    |> Enum.group_by(& &1.category)
    |> Enum.each(fn {category, items} ->
      Logger.info("  #{category}: #{length(items)} items")
    end)
    
    # Log threat level distribution
    threat_levels = trends |> Enum.map(& &1.threat_level) |> Enum.frequencies()
    Logger.info("  Threat level distribution: #{inspect(threat_levels)}")
    
    # Log high-threat items in detail
    high_threat_items = trends |> Enum.filter(&(&1.threat_level >= 70))
    if length(high_threat_items) > 0 do
      Logger.warning("🚨 HIGH THREAT ITEMS DETECTED:")
      high_threat_items
      |> Enum.take(5)
      |> Enum.each(fn item ->
        Logger.warning("  ⚠️  [#{item.threat_level}] #{item.category}: #{item.title}")
        Logger.warning("      Source: #{item.source} | Urgency: #{item.urgency} | Scope: #{item.geographic_scope}")
      end)
    end
    
    # Log sample of raw titles for debugging
    Logger.debug("📋 Sample trend titles:")
    trends
    |> Enum.take(10)
    |> Enum.with_index(1)
    |> Enum.each(fn {item, index} ->
      Logger.debug("  #{index}. [#{item.category}] #{item.title}")
    end)
    
    trends
  end

  defp log_final_trends_summary(final_trends) do
    Logger.info("📊 Final processed trends summary:")
    
    # Category breakdown
    category_counts = final_trends |> Enum.group_by(& &1.category) |> Enum.map(fn {k, v} -> {k, length(v)} end)
    Logger.info("  Categories represented: #{inspect(category_counts)}")
    
    # Threat level stats
    threat_levels = final_trends |> Enum.map(& &1.threat_level)
    avg_threat = if length(threat_levels) > 0, do: Enum.sum(threat_levels) / length(threat_levels), else: 0
    max_threat = Enum.max(threat_levels, fn -> 0 end)
    Logger.info("  Threat levels - Avg: #{Float.round(avg_threat, 1)}, Max: #{max_threat}")
    
    # Urgency breakdown
    urgency_counts = final_trends |> Enum.group_by(& &1.urgency) |> Enum.map(fn {k, v} -> {k, length(v)} end)
    Logger.info("  Urgency levels: #{inspect(urgency_counts)}")
    
    # Geographic scope
    geo_counts = final_trends |> Enum.group_by(& &1.geographic_scope) |> Enum.map(fn {k, v} -> {k, length(v)} end)
    Logger.info("  Geographic scope: #{inspect(geo_counts)}")
    
    # Top 3 highest threat items
    Logger.info("🏆 Top 3 highest threat trends:")
    final_trends
    |> Enum.take(3)
    |> Enum.with_index(1)
    |> Enum.each(fn {item, rank} ->
      Logger.info("  #{rank}. [#{item.threat_level}] #{item.title}")
      Logger.info("      📍 #{item.geographic_scope} | ⏰ #{item.urgency} | 📰 #{item.source}")
    end)
  end

  # Extract text using Floki
  defp extract_floki_text(item_element, tag_name) do
    case Floki.find(item_element, tag_name) do
      [element] -> Floki.text(element) |> String.trim()
      [] -> ""
      _multiple -> 
        # Take first if multiple found
        Floki.find(item_element, tag_name) |> List.first() |> Floki.text() |> String.trim()
    end
  rescue
    _ -> ""
  end

  defp extract_source_from_floki_description(description) do
    # Try to extract source from Google News description format
    case Regex.run(~r/<font color="#6f6f6f">([^<]+)<\/font>/, description || "") do
      [_, source] -> String.trim(source)
      _ -> 
        # Fallback: try to find source in simpler format
        case Regex.run(~r/- ([A-Za-z\s]+)$/, description || "") do
          [_, source] -> String.trim(source)
          _ -> "Unknown Source"
        end
    end
  end

  # Keep old extract_text function for backwards compatibility
  defp extract_text(element, tag_name) when is_atom(tag_name) do
    xpath_query = ~c".//#{tag_name}/text()"
    case :xmerl_xpath.string(xpath_query, element) do
      [text_node | _] -> 
        text_node 
        |> :xmerl_lib.export_text() 
        |> List.to_string()
        |> String.trim()
      [] -> ""
    end
  rescue
    _ -> ""
  end
end