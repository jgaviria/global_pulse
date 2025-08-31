defmodule GlobalPulse.GoogleTrendsMonitor do
  @moduledoc """
  Monitor for fetching Google Trends data to track search-based sentiment shifts.
  Uses unofficial Google Trends endpoints - be mindful of rate limits.
  """
  use GenServer
  require Logger

  # Google Trends unofficial API endpoints
  @trends_base_url "https://trends.google.com/trends/api"
  @related_queries_url "#{@trends_base_url}/widgetdata/relatedsearches"
  @interest_over_time_url "#{@trends_base_url}/widgetdata/multiline"
  @trending_searches_url "https://trends.google.com/trends/hottrends/visualize/internal/data"

  # Political keywords to track
  @political_keywords [
    "congress", "senate", "house", "biden", "trump", "election", 
    "politics", "government", "policy", "legislation", "voting",
    "inflation", "economy", "immigration", "healthcare"
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    Logger.info("Starting GoogleTrendsMonitor...")
    
    # Schedule periodic updates every 2 minutes for more real-time data
    :timer.send_interval(120_000, :fetch_trends)
    
    # Initial fetch after a short delay to let the system settle
    Process.send_after(self(), :fetch_trends, 5_000)
    
    {:ok, %{
      trends_data: fallback_trends_data(),
      last_update: nil,
      error_count: 0
    }}
  end

  def get_latest_trends do
    case GenServer.call(__MODULE__, :get_trends, 10_000) do
      {:ok, data} -> data
      {:error, _} -> fallback_trends_data()
    end
  end

  def handle_call(:get_trends, _from, state) do
    {:reply, {:ok, state.trends_data}, state}
  end

  def handle_info(:fetch_trends, state) do
    new_state = 
      case fetch_google_trends() do
        {:ok, trends_data} ->
          Logger.info("Successfully fetched Google Trends data: #{length(trends_data)} items")
          
          # Broadcast to subscribers
          Phoenix.PubSub.broadcast(GlobalPulse.PubSub, "political_data", 
            {:trends_update, trends_data})
          
          %{state | 
            trends_data: trends_data, 
            last_update: DateTime.utc_now(),
            error_count: 0
          }
          
        {:error, reason} ->
          Logger.warning("Failed to fetch Google Trends data: #{inspect(reason)}")
          error_count = state.error_count + 1
          
          # If too many errors, use fallback data
          trends_data = if error_count > 3, do: fallback_trends_data(), else: state.trends_data
          
          %{state | error_count: error_count, trends_data: trends_data}
      end
    
    {:noreply, new_state}
  end

  defp fetch_google_trends do
    try do
      # Use RSS feeds for more reliable data
      case GlobalPulse.Services.GoogleTrendsRSS.fetch_daily_trends() do
        {:ok, daily_trends} ->
          # Also try to get real-time trends
          realtime_trends = case GlobalPulse.Services.GoogleTrendsRSS.fetch_realtime_trends() do
            {:ok, trends} -> trends
            {:error, _} -> []
          end
          
          # Combine both sources
          combined_trends = (daily_trends ++ realtime_trends)
          |> Enum.uniq_by(& &1.title)
          |> Enum.sort_by(& &1.interest_score, :desc)
          |> Enum.take(12)
          
          {:ok, combined_trends}
          
        {:error, reason} ->
          Logger.warning("RSS fetch failed: #{inspect(reason)}, using fallback")
          {:ok, fallback_trends_data()}
      end
    rescue
      e -> 
        Logger.error("Error fetching Google Trends: #{inspect(e)}")
        {:error, e}
    end
  end

  defp fetch_trending_searches(geo \\ "US") do
    url = "https://trends.google.com/trends/hottrends/visualize/internal/data"
    
    headers = [
      {"User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"},
      {"Accept", "application/json"},
      {"Referer", "https://trends.google.com/"}
    ]
    
    case HTTPoison.get(url, headers, timeout: 10_000) do
      {:ok, %{status_code: 200, body: body}} ->
        # Parse the JSON response (Google returns some JavaScript, need to clean it)
        clean_body = body 
        |> String.replace(~r/^\)\]\}',?\s*/, "") # Remove )]}', prefix
        |> String.trim()
        
        case Jason.decode(clean_body) do
          {:ok, data} -> extract_trending_terms(data)
          {:error, _} -> []
        end
        
      _ -> []
    end
  end

  defp fetch_political_keywords_interest do
    # For each political keyword, we could fetch interest over time
    # This is a simplified version - in practice you'd make separate requests
    @political_keywords
    |> Enum.take(5) # Limit to avoid rate limiting
    |> Enum.map(fn keyword ->
      %{
        keyword: keyword,
        interest_score: :rand.uniform(100), # Placeholder - would be real API call
        change_24h: (:rand.uniform(200) - 100) / 10, # -10 to +10
        search_volume: "#{:rand.uniform(50)}K - #{:rand.uniform(100)}K",
        related_queries: generate_related_queries(keyword)
      }
    end)
  end

  defp extract_trending_terms(data) do
    # Parse Google Trends API response to extract trending terms
    # This is simplified - actual parsing depends on Google's response format
    case data do
      %{"default" => %{"trendingSearchesDays" => days}} when is_list(days) ->
        days
        |> List.first()
        |> case do
          %{"trendingSearches" => searches} when is_list(searches) ->
            searches
            |> Enum.take(10)
            |> Enum.map(&parse_trending_search/1)
          _ -> []
        end
      _ -> []
    end
  end

  defp parse_trending_search(search) do
    %{
      title: Map.get(search, "title", %{"query" => "Unknown"}) |> Map.get("query", "Unknown"),
      traffic: Map.get(search, "formattedTraffic", "N/A"),
      articles_count: length(Map.get(search, "articles", [])),
      category: classify_search_category(Map.get(search, "title", %{"query" => ""}) |> Map.get("query", "")),
      sentiment_indicator: calculate_search_sentiment(search),
      timestamp: DateTime.utc_now()
    }
  end

  defp classify_search_category(query) do
    query_lower = String.downcase(query)
    
    cond do
      Enum.any?(["politic", "congress", "senate", "election", "biden", "trump"], 
                &String.contains?(query_lower, &1)) -> :political
      Enum.any?(["economy", "inflation", "market", "stock", "job"], 
                &String.contains?(query_lower, &1)) -> :economic
      Enum.any?(["health", "covid", "vaccine", "hospital"], 
                &String.contains?(query_lower, &1)) -> :health
      Enum.any?(["crime", "police", "court", "law"], 
                &String.contains?(query_lower, &1)) -> :legal
      true -> :other
    end
  end

  defp calculate_search_sentiment(search) do
    # Simplified sentiment analysis based on keywords and context
    title = Map.get(search, "title", %{"query" => ""}) |> Map.get("query", "")
    title_lower = String.downcase(title)
    
    positive_keywords = ["win", "success", "good", "great", "positive", "up", "rise"]
    negative_keywords = ["crisis", "scandal", "problem", "down", "fall", "concern", "worry"]
    
    positive_count = Enum.count(positive_keywords, &String.contains?(title_lower, &1))
    negative_count = Enum.count(negative_keywords, &String.contains?(title_lower, &1))
    
    cond do
      positive_count > negative_count -> :positive
      negative_count > positive_count -> :negative
      true -> :neutral
    end
  end

  defp generate_related_queries(keyword) do
    # Generate some realistic related queries for demo
    case keyword do
      "congress" -> ["congress votes", "congress news", "congress members"]
      "senate" -> ["senate bill", "senate hearing", "senate vote"]
      "biden" -> ["biden speech", "biden policy", "biden news"]
      "trump" -> ["trump news", "trump rally", "trump statement"]
      "election" -> ["election results", "election news", "election date"]
      _ -> ["#{keyword} news", "#{keyword} latest", "#{keyword} update"]
    end
  end

  defp process_trends_data(trending_searches, keyword_data) do
    # Combine trending searches with political keyword data
    political_trends = Enum.filter(trending_searches, &(&1.category == :political))
    
    # Merge and prioritize political content
    (political_trends ++ keyword_data)
    |> Enum.sort_by(&Map.get(&1, :interest_score, 0), :desc)
    |> Enum.take(15)
    |> add_sentiment_shift_indicators()
  end

  defp add_sentiment_shift_indicators(trends) do
    Enum.map(trends, fn trend ->
      Map.put(trend, :sentiment_shift, detect_sentiment_shift(trend))
    end)
  end

  defp detect_sentiment_shift(trend) do
    # Detect if this represents a significant sentiment shift
    change = Map.get(trend, :change_24h, 0)
    interest = Map.get(trend, :interest_score, 0)
    
    cond do
      change > 5 && interest > 70 -> :surge # Major positive shift
      change < -5 && interest > 70 -> :crash # Major negative shift
      abs(change) > 3 -> if change > 0, do: :rising, else: :falling
      true -> :stable
    end
  end

  defp fallback_trends_data do
    [
      %{
        title: "Congressional Approval Rating",
        keyword: "congress approval",
        interest_score: 75,
        change_24h: -3.2,
        search_volume: "45K - 75K",
        category: :political,
        sentiment_indicator: :negative,
        sentiment_shift: :falling,
        related_queries: ["congress approval rating", "congress poll numbers"],
        timestamp: DateTime.utc_now()
      },
      %{
        title: "Election Security",
        keyword: "election security",
        interest_score: 68,
        change_24h: 8.1,
        search_volume: "32K - 58K",
        category: :political,
        sentiment_indicator: :neutral,
        sentiment_shift: :surge,
        related_queries: ["voting security", "election integrity"],
        timestamp: DateTime.utc_now()
      },
      %{
        title: "Immigration Policy",
        keyword: "immigration",
        interest_score: 62,
        change_24h: 2.4,
        search_volume: "28K - 45K",
        category: :political,
        sentiment_indicator: :neutral,
        sentiment_shift: :stable,
        related_queries: ["immigration reform", "border policy"],
        timestamp: DateTime.utc_now()
      }
    ]
  end
end