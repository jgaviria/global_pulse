defmodule GlobalPulseWeb.PoliticalLive.Index do
  use GlobalPulseWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "political_data")
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "anomalies")
      
      # Schedule less frequent data refresh to avoid interfering with smooth chart
      :timer.send_interval(10000, self(), :fetch_data)
    end

    # Get initial data from the monitor and live sources
    initial_data = fetch_political_data()
    google_trends = fetch_google_trends_data()
    live_news = fetch_live_news_feed()

    {:ok,
     socket
     |> assign(:page_title, "Political Climate")
     |> assign(:active_tab, :political)
     |> assign(:last_update, DateTime.utc_now())
     |> assign(:anomaly_count, 0)
     |> assign(:news_articles, live_news)
     |> assign(:sentiment_analysis, initial_data.sentiment || %{overall: 0, news: 0, social: 0})
     |> assign(:trending_topics, initial_data.trending || [])
     |> assign(:events, initial_data.events || [])
     |> assign(:social_trends, initial_data.social || [])
     |> assign(:google_trends, google_trends)}
  end

  @impl true
  def handle_info({:update, data}, socket) do
    {:noreply,
     socket
     |> assign(:news_articles, data[:news] || [])
     |> assign(:sentiment_analysis, data[:sentiment] || %{})
     |> assign(:events, data[:events] || [])
     |> assign(:social_trends, data[:social] || [])
     |> assign(:last_update, DateTime.utc_now())}
  end

  def handle_info(:fetch_data, socket) do
    data = fetch_political_data()
    google_trends = fetch_google_trends_data()
    live_news = fetch_live_news_feed()
    
    {:noreply,
     socket
     |> assign(:news_articles, live_news)
     |> assign(:sentiment_analysis, data.sentiment || %{overall: 0, news: 0, social: 0})
     |> assign(:trending_topics, data.trending || [])
     |> assign(:events, data.events || [])
     |> assign(:social_trends, data.social || [])
     |> assign(:google_trends, google_trends)
     |> assign(:last_update, DateTime.utc_now())}
  end

  def handle_info({:trends_update, trends_data}, socket) do
    {:noreply, assign(socket, :google_trends, trends_data)}
  end

  def handle_info({:new_anomalies, anomalies}, socket) do
    political_anomalies = Enum.filter(anomalies, &(&1[:type] in [:sentiment_shift, :trending_spike, :breaking_news_cluster]))
    {:noreply, assign(socket, :anomaly_count, length(political_anomalies))}
  end
  
  defp fetch_political_data do
    try do
      case GlobalPulse.Services.NewsAggregator.fetch_all_news() do
        {:ok, articles} -> 
          Logger.debug("📰 Fetched #{length(articles)} articles from NewsAggregator")
          process_aggregated_news_data(articles)
        _ -> 
          Logger.warning("📰 NewsAggregator unavailable, using monitor fallback")
          case GlobalPulse.PoliticalMonitor.get_latest_data() do
            data when is_map(data) -> data
            _ -> fallback_political_data()
          end
      end
    rescue
      e ->
        Logger.warning("📰 Error fetching political data: #{inspect(e)}")
        fallback_political_data()
    end
  end

  defp fetch_google_trends_data do
    try do
      case GlobalPulse.Services.GoogleTrendsRSS.fetch_daily_trends() do
        {:ok, trends} when is_list(trends) and length(trends) > 0 -> 
          Logger.debug("📈 Fetched #{length(trends)} Google Trends from RSS")
          trends
        _ -> 
          Logger.debug("📈 Google Trends RSS unavailable, using monitor fallback")
          case GlobalPulse.GoogleTrendsMonitor.get_latest_trends() do
            trends when is_list(trends) and length(trends) > 0 -> trends
            _ -> fallback_google_trends_data()
          end
      end
    rescue
      e ->
        Logger.warning("📈 Error fetching Google Trends: #{inspect(e)}")
        fallback_google_trends_data()
    end
  end

  defp fetch_live_news_feed do
    try do
      case GlobalPulse.Services.LiveNewsFeed.fetch_live_news_feed(15) do
        {:ok, articles} when is_list(articles) and length(articles) > 0 -> 
          Logger.debug("📰 Fetched #{length(articles)} live news articles")
          articles
        _ -> 
          # Fallback to political monitor data
          case fetch_political_data() do
            %{news: news} when is_list(news) -> news
            _ -> fallback_news_articles()
          end
      end
    rescue
      e ->
        Logger.warning("📰 Live news feed error: #{inspect(e)}")
        fallback_news_articles()
    end
  end

  defp fallback_news_articles do
    [
      %{
        title: "Global Economic Markets Show Volatility",
        description: "International markets respond to recent policy announcements",
        source: "Financial Times",
        published_at: DateTime.utc_now(),
        sentiment: -0.1,
        importance_score: 0.7,
        category: "economy"
      },
      %{
        title: "International Summit Addresses Climate Policy",
        description: "World leaders discuss coordinated response to environmental challenges",
        source: "Reuters",
        published_at: DateTime.add(DateTime.utc_now(), -3600, :second),
        sentiment: 0.2,
        importance_score: 0.8,
        category: "environment"
      },
      %{
        title: "Technology Sector Faces New Regulations",
        description: "Government announces oversight measures for digital platforms",
        source: "Tech News",
        published_at: DateTime.add(DateTime.utc_now(), -7200, :second),
        sentiment: 0.0,
        importance_score: 0.6,
        category: "technology"
      }
    ]
  end

  defp fallback_google_trends_data do
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

  defp fallback_political_data do
    %{
      news: [
        %{
          title: "Congressional Budget Negotiations Continue",
          description: "House and Senate leaders work on fiscal year spending priorities",
          source: "Capitol News",
          published_at: DateTime.utc_now(),
          url: "#",
          sentiment: 0.1,
          categories: ["politics", "budget"],
          importance_score: 0.7
        },
        %{
          title: "Federal Reserve Chair Addresses Economic Policy",
          description: "Central bank official discusses monetary policy outlook at Capitol Hill hearing",
          source: "Economic Wire",
          published_at: DateTime.add(DateTime.utc_now(), -1800, :second),
          url: "#",
          sentiment: -0.1,
          categories: ["economics", "policy"],
          importance_score: 0.8
        },
        %{
          title: "Supreme Court Considers Key Constitutional Case",
          description: "Justices hear arguments on federal versus state authority dispute",
          source: "Legal Times",
          published_at: DateTime.add(DateTime.utc_now(), -3600, :second),
          url: "#",
          sentiment: 0.0,
          categories: ["legal", "constitutional"],
          importance_score: 0.9
        },
        %{
          title: "Senate Committee Advances Climate Legislation",
          description: "Bipartisan environmental bill moves forward after lengthy negotiations",
          source: "Environmental Report",
          published_at: DateTime.add(DateTime.utc_now(), -5400, :second),
          url: "#",
          sentiment: 0.25,
          categories: ["environment", "legislation"],
          importance_score: 0.75
        },
        %{
          title: "Treasury Secretary Addresses Banking Regulations",
          description: "New financial oversight measures proposed for regional banks",
          source: "Financial Daily",
          published_at: DateTime.add(DateTime.utc_now(), -7200, :second),
          url: "#",
          sentiment: -0.1,
          categories: ["finance", "regulation"],
          importance_score: 0.65
        },
        %{
          title: "Congressional Leaders Meet on Defense Spending",
          description: "Military budget priorities discussed in closed-door session",
          source: "Defense Weekly",
          published_at: DateTime.add(DateTime.utc_now(), -9000, :second),
          url: "#",
          sentiment: 0.15,
          categories: ["defense", "budget"],
          importance_score: 0.8
        },
        %{
          title: "Immigration Reform Talks Continue",
          description: "House and Senate negotiators work on comprehensive immigration bill",
          source: "Immigration Today",
          published_at: DateTime.add(DateTime.utc_now(), -10800, :second),
          url: "#",
          sentiment: 0.05,
          categories: ["immigration", "reform"],
          importance_score: 0.85
        }
      ],
      sentiment: %{overall: 0.05, news: 0.1, social: -0.05, political_stability: 0.65},
      trending: [
        %{
          title: "Budget Negotiations Discussion Thread",
          score: 1450,
          comments: 324,
          author: "policy_watcher",
          created_at: DateTime.utc_now(),
          subreddit: "politics",
          url: "#",
          sentiment: 0.2,
          engagement_rate: 4.5
        },
        %{
          title: "Fed Policy Impact Analysis",
          score: 1120,
          comments: 198,
          author: "economic_analyst",
          created_at: DateTime.add(DateTime.utc_now(), -900, :second),
          subreddit: "politics",
          url: "#",
          sentiment: -0.1,
          engagement_rate: 5.7
        }
      ],
      events: [
        %{
          title: "Congressional Budget Hearing",
          date: DateTime.add(DateTime.utc_now(), 2 * 24 * 3600, :second),
          location: "Washington, D.C.",
          type: "legislative",
          impact_score: 0.8,
          description: "House Budget Committee reviews federal spending proposals"
        },
        %{
          title: "Federal Reserve Meeting",
          date: DateTime.add(DateTime.utc_now(), 5 * 24 * 3600, :second),
          location: "Washington, D.C.",
          type: "economic",
          impact_score: 0.9,
          description: "FOMC discusses interest rate policy decisions"
        }
      ],
      social: [
        %{
          platform: "twitter",
          hashtag: "#Politics",
          volume: 175_000,
          sentiment: 0.1,
          growth_rate: 0.6,
          timestamp: DateTime.utc_now()
        },
        %{
          platform: "twitter",
          hashtag: "#Congress",
          volume: 89_000,
          sentiment: -0.2,
          growth_rate: 0.8,
          timestamp: DateTime.utc_now()
        },
        %{
          platform: "reddit",
          topic: "Political Discussion",
          volume: 67_000,
          sentiment: 0.05,
          growth_rate: 0.4,
          timestamp: DateTime.utc_now()
        }
      ]
    }
  end

  defp format_change(value) when is_integer(value) do
    Float.round(value * 1.0, 2)
  end
  defp format_change(value) when is_float(value) do
    Float.round(value, 2)
  end
  
  defp political_sentiment_class(sentiment) when sentiment > 0.2, do: "bg-green-500/20 text-green-400"
  defp political_sentiment_class(sentiment) when sentiment < -0.2, do: "bg-red-500/20 text-red-400"
  defp political_sentiment_class(_), do: "bg-yellow-500/20 text-yellow-400"
  
  defp political_sentiment_color(sentiment) when sentiment > 0.2, do: "text-green-400"
  defp political_sentiment_color(sentiment) when sentiment < -0.2, do: "text-red-400"
  defp political_sentiment_color(_), do: "text-yellow-400"
  
  defp political_sentiment_label(sentiment) when sentiment > 0.2, do: "Positive"
  defp political_sentiment_label(sentiment) when sentiment < -0.2, do: "Negative"
  defp political_sentiment_label(_), do: "Neutral"
  
  defp political_event_impact_color(impact) when impact > 0.7, do: "bg-red-500"
  defp political_event_impact_color(impact) when impact > 0.4, do: "bg-yellow-500"  
  defp political_event_impact_color(_), do: "bg-green-500"
  
  defp political_impact_badge(impact) when impact > 0.7, do: "bg-red-500/20 text-red-400"
  defp political_impact_badge(impact) when impact > 0.4, do: "bg-yellow-500/20 text-yellow-400"
  defp political_impact_badge(_), do: "bg-green-500/20 text-green-400"
  
  defp political_format_large_number(num) when num > 1_000_000 do
    "#{Float.round(num / 1_000_000, 1)}M"
  end
  defp political_format_large_number(num) when num > 1_000 do
    "#{Float.round(num / 1_000, 1)}K"
  end
  defp political_format_large_number(num), do: to_string(num)
  
  defp format_time(nil), do: "Never"
  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S UTC")
  end

  # Google Trends helper functions
  defp trends_sentiment_shift_class(:surge), do: "bg-red-500/20 text-red-400 animate-pulse"
  defp trends_sentiment_shift_class(:crash), do: "bg-red-600/20 text-red-500 animate-pulse"  
  defp trends_sentiment_shift_class(:rising), do: "bg-green-500/20 text-green-400"
  defp trends_sentiment_shift_class(:falling), do: "bg-orange-500/20 text-orange-400"
  defp trends_sentiment_shift_class(:stable), do: "bg-gray-500/20 text-gray-400"

  defp trends_sentiment_shift_icon(:surge), do: "🚀"
  defp trends_sentiment_shift_icon(:crash), do: "💥"
  defp trends_sentiment_shift_icon(:rising), do: "📈"
  defp trends_sentiment_shift_icon(:falling), do: "📉"
  defp trends_sentiment_shift_icon(:stable), do: "➡️"

  defp trends_category_color(:political), do: "text-red-400"
  defp trends_category_color(:economic), do: "text-green-400"
  defp trends_category_color(:health), do: "text-blue-400"
  defp trends_category_color(:legal), do: "text-purple-400"
  defp trends_category_color(_), do: "text-gray-400"

  defp format_trends_change(change) when change > 0, do: "+#{:erlang.float_to_binary(change, [{:decimals, 1}])}%"
  defp format_trends_change(change), do: "#{:erlang.float_to_binary(change, [{:decimals, 1}])}%"

  defp process_aggregated_news_data(articles) do
    # Convert NewsAggregator articles to expected political data format
    political_articles = articles
    |> Enum.filter(fn article -> 
      "politics" in (article.categories || []) || 
      "conflict" in (article.categories || []) ||
      "social_unrest" in (article.categories || [])
    end)
    |> Enum.take(20)
    |> Enum.map(&convert_article_format/1)

    # Calculate overall sentiment from articles
    overall_sentiment = if length(political_articles) > 0 do
      articles 
      |> Enum.map(&(&1.sentiment || 0))
      |> Enum.sum()
      |> Kernel./(length(articles))
    else
      0.0
    end

    # Extract trending topics from social unrest and political articles
    trending_topics = articles
    |> Enum.filter(fn article -> 
      article.importance_score && article.importance_score > 0.7
    end)
    |> Enum.take(10)
    |> Enum.map(fn article ->
      %{
        title: article.title,
        score: trunc((article.importance_score || 0.5) * 1000),
        comments: 0,
        author: article.source,
        created_at: article.published_at,
        subreddit: "news",
        url: article.url,
        sentiment: article.sentiment || 0.0,
        engagement_rate: article.importance_score || 0.5
      }
    end)

    # Extract upcoming events based on articles
    events = extract_events_from_articles(political_articles)

    # Create social trends from article categories
    social_trends = create_social_trends_from_articles(articles)

    %{
      news: political_articles,
      sentiment: %{
        overall: overall_sentiment,
        news: overall_sentiment,
        social: overall_sentiment * 0.8,
        political_stability: max(0.0, 1.0 - abs(overall_sentiment))
      },
      trending: trending_topics,
      events: events,
      social: social_trends
    }
  end

  defp convert_article_format(article) do
    %{
      title: article.title,
      description: article.description || "",
      source: article.source,
      published_at: article.published_at,
      url: article.url || "#",
      sentiment: article.sentiment || 0.0,
      categories: article.categories || ["general"],
      importance_score: article.importance_score || 0.5,
      threat_level: Map.get(article, :threat_level, 20),
      urgency: Map.get(article, :urgency, :normal)
    }
  end

  defp extract_events_from_articles(articles) do
    articles
    |> Enum.filter(fn article ->
      text = String.downcase("#{article.title} #{article.description}")
      String.contains?(text, ["summit", "meeting", "conference", "hearing", "election", "vote"])
    end)
    |> Enum.take(5)
    |> Enum.map(fn article ->
      %{
        title: article.title,
        date: DateTime.add(DateTime.utc_now(), :rand.uniform(7) * 24 * 3600, :second),
        location: extract_location_from_article(article),
        type: categorize_event_type(article),
        impact_score: article.importance_score || 0.5,
        description: article.description
      }
    end)
  end

  defp extract_location_from_article(article) do
    text = String.downcase("#{article.title} #{article.description}")
    cond do
      String.contains?(text, ["washington", "capitol", "white house"]) -> "Washington, D.C."
      String.contains?(text, ["brussels", "eu", "europe"]) -> "Brussels, EU"
      String.contains?(text, ["beijing", "china"]) -> "Beijing, China"
      String.contains?(text, ["moscow", "russia"]) -> "Moscow, Russia"
      String.contains?(text, ["london", "uk", "britain"]) -> "London, UK"
      true -> "International"
    end
  end

  defp categorize_event_type(article) do
    text = String.downcase("#{article.title} #{article.description}")
    cond do
      String.contains?(text, ["election", "vote", "campaign"]) -> "electoral"
      String.contains?(text, ["summit", "meeting", "conference"]) -> "diplomatic"
      String.contains?(text, ["hearing", "congress", "parliament"]) -> "legislative"
      String.contains?(text, ["military", "defense", "security"]) -> "security"
      String.contains?(text, ["economic", "trade", "market"]) -> "economic"
      true -> "political"
    end
  end

  defp create_social_trends_from_articles(articles) do
    # Create mock social trends based on article categories and sentiment
    category_counts = articles
    |> Enum.flat_map(&(&1.categories || ["general"]))
    |> Enum.frequencies()

    category_counts
    |> Enum.take(5)
    |> Enum.map(fn {category, count} ->
      sentiment = articles
      |> Enum.filter(fn article -> category in (article.categories || []) end)
      |> Enum.map(&(&1.sentiment || 0))
      |> case do
        [] -> 0.0
        sentiments -> Enum.sum(sentiments) / length(sentiments)
      end

      %{
        platform: "aggregated",
        hashtag: "##{String.capitalize(category)}",
        volume: count * 1000,
        sentiment: sentiment,
        growth_rate: :rand.uniform() * 2 - 1,
        timestamp: DateTime.utc_now()
      }
    end)
  end
end