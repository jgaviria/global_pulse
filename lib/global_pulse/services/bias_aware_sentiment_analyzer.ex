defmodule GlobalPulse.Services.BiasAwareSentimentAnalyzer do
  @moduledoc """
  Advanced sentiment analysis system designed to minimize cultural, linguistic, 
  and geographic biases in global news sentiment calculation.
  
  Features:
  - Multi-lingual sentiment analysis
  - Geographic context weighting  
  - Source diversity balancing
  - Cultural bias adjustment
  - Historical baseline comparison
  - Transparency reporting
  """
  
  require Logger
  
  # Language detection patterns (simplified - in production use a proper language detection library)
  @language_patterns %{
    "es" => ~w[el la los las un una de del que en con por para],
    "fr" => ~w[le la les un une de du que dans avec pour],
    "ar" => ~w[في من على إلى عن مع هذا هذه التي],
    "zh" => ~w[的 在 是 了 我 你 他 她 们],
    "ru" => ~w[в на с по от до из за что это],
    "pt" => ~w[o a os as um uma de do que em com por para],
    "de" => ~w[der die das ein eine und mit für von zu],
    "ja" => ~w[の を に は が で と から まで],
    "hi" => ~w[के का की में से और को भी यह वह]
  }
  
  # Regional baselines for sentiment context
  @regional_baselines %{
    "north_america" => %{sentiment: 0.0, stability: 0.8, baseline_adjust: 0.0},
    "europe" => %{sentiment: 0.1, stability: 0.85, baseline_adjust: 0.05},
    "middle_east" => %{sentiment: -0.2, stability: 0.4, baseline_adjust: -0.15},
    "africa" => %{sentiment: -0.1, stability: 0.5, baseline_adjust: -0.1},
    "asia_pacific" => %{sentiment: 0.05, stability: 0.7, baseline_adjust: 0.0},
    "latin_america" => %{sentiment: -0.05, stability: 0.6, baseline_adjust: -0.05},
    "unknown" => %{sentiment: 0.0, stability: 0.6, baseline_adjust: 0.0}
  }
  
  # Source origin mapping for diversity balancing
  @source_regions %{
    "bbc" => "europe",
    "reuters" => "europe", 
    "cnn" => "north_america",
    "npr" => "north_america",
    "aljazeera" => "middle_east",
    "guardian" => "europe",
    "ap_news" => "north_america",
    "el_pais" => "europe",  # Spain-based but covers Latin America extensively
    "reddit" => "north_america"
  }
  
  @doc """
  Analyze sentiment of articles with bias awareness and cultural context
  """
  def analyze_articles_sentiment(articles) when is_list(articles) do
    Logger.info("🧠 BIAS-AWARE SENTIMENT: Analyzing #{length(articles)} articles")
    
    # Step 1: Individual article analysis with multi-lingual support
    analyzed_articles = articles
    |> Enum.map(&analyze_single_article/1)
    |> Enum.reject(&is_nil/1)
    
    # Step 2: Calculate diversity-balanced sentiment
    balanced_sentiment = calculate_balanced_sentiment(analyzed_articles)
    
    # Step 3: Apply geographic and cultural context
    contextualized_sentiment = apply_geographic_context(balanced_sentiment, analyzed_articles)
    
    # Step 4: Historical baseline adjustment
    adjusted_sentiment = apply_historical_baseline(contextualized_sentiment, analyzed_articles)
    
    # Step 5: Generate transparency report
    bias_report = generate_bias_report(analyzed_articles, balanced_sentiment, contextualized_sentiment, adjusted_sentiment)
    
    %{
      overall_sentiment: adjusted_sentiment,
      raw_sentiment: balanced_sentiment,
      contextualized_sentiment: contextualized_sentiment,
      bias_report: bias_report,
      article_count: length(analyzed_articles),
      confidence: calculate_confidence(analyzed_articles, bias_report)
    }
  end
  
  # ============================================================================
  # MULTI-LINGUAL SENTIMENT ANALYSIS
  # ============================================================================
  
  defp analyze_single_article(article) do
    title = Map.get(article, :title, "")
    description = Map.get(article, :description, "")
    source = Map.get(article, :source, "")
    
    text = "#{title} #{description}"
    
    # Skip if no actual text content
    if String.trim(text) == "" do
      nil
    else
      # Detect language and region
      language = detect_language(text)
      region = detect_article_region(article)
      source_region = Map.get(@source_regions, String.downcase(source), "unknown")
    
    # Multi-lingual sentiment analysis
    base_sentiment = case language do
      "en" -> analyze_english_sentiment(text)
      "es" -> analyze_spanish_sentiment(text) 
      "ar" -> analyze_arabic_sentiment(text)
      "zh" -> analyze_chinese_sentiment(text)
      "ru" -> analyze_russian_sentiment(text)
      "fr" -> analyze_french_sentiment(text)
      "de" -> analyze_german_sentiment(text)
      _ -> analyze_universal_sentiment(text)  # Fallback for other languages
    end
    
    # Cultural context adjustment
    cultural_sentiment = adjust_for_cultural_context(base_sentiment, language, region)
    
    %{
      article: article,
      language: language,
      region: region,
      source_region: source_region,
      base_sentiment: base_sentiment,
      cultural_sentiment: cultural_sentiment,
      importance: Map.get(article, :importance_score, 0.5)
    }
    end
  rescue
    e ->
      Logger.warning("Failed to analyze article sentiment: #{inspect(e)}")
      nil
  end
  
  # ============================================================================
  # LANGUAGE-SPECIFIC SENTIMENT ANALYZERS
  # ============================================================================
  
  defp analyze_english_sentiment(text) do
    text = String.downcase(text)
    
    # Enhanced English sentiment with cultural awareness
    positive_keywords = [
      # Universal positives
      "peace", "agreement", "cooperation", "stability", "progress", "success",
      "improvement", "recovery", "breakthrough", "resolution", "unity", "growth",
      # Democratic/Western positives
      "democracy", "freedom", "rights", "election", "vote", "transparency",
      # Economic positives
      "prosperity", "development", "investment", "innovation"
    ]
    
    negative_keywords = [
      # Universal negatives  
      "war", "conflict", "violence", "crisis", "attack", "terrorism", "death",
      "destruction", "collapse", "failure", "decline", "chaos", "disaster",
      # Social negatives
      "protest", "riot", "unrest", "tension", "dispute", "corruption",
      # Economic negatives
      "recession", "unemployment", "poverty", "inflation", "sanctions"
    ]
    
    calculate_keyword_sentiment(text, positive_keywords, negative_keywords)
  end
  
  defp analyze_spanish_sentiment(text) do
    text = String.downcase(text)
    
    positive_keywords = [
      # Spanish positives with cultural context
      "paz", "acuerdo", "cooperación", "estabilidad", "progreso", "éxito",
      "mejora", "recuperación", "avance", "resolución", "unidad", "crecimiento",
      "democracia", "libertad", "derechos", "elección", "voto", "transparencia",
      "prosperidad", "desarrollo", "inversión", "innovación"
    ]
    
    negative_keywords = [
      "guerra", "conflicto", "violencia", "crisis", "ataque", "terrorismo", "muerte",
      "destrucción", "colapso", "fracaso", "declive", "caos", "desastre",
      "protesta", "disturbio", "tensión", "disputa", "corrupción",
      "recession", "desempleo", "pobreza", "inflación", "sanciones"
    ]
    
    calculate_keyword_sentiment(text, positive_keywords, negative_keywords)
  end
  
  defp analyze_arabic_sentiment(text) do
    text = String.downcase(text)
    
    # Arabic sentiment with Middle Eastern cultural context
    positive_keywords = [
      # Arabic positives (romanized for now - in production use proper Arabic)
      "salam", "ittifaq", "ta'awun", "istiqrar", "taqaddum", "najah",
      "tahsin", "isti'ada", "hall", "wahda", "numuw"
    ]
    
    negative_keywords = [
      "harb", "sira'", "unf", "azma", "hujum", "irhab", "mawt",
      "tadmir", "inhiyar", "fashal", "tadahur", "fawda"
    ]
    
    sentiment = calculate_keyword_sentiment(text, positive_keywords, negative_keywords)
    # Adjust for Middle Eastern context - stability news may be more positive
    sentiment + 0.1
  end
  
  defp analyze_chinese_sentiment(text) do
    text = String.downcase(text)
    
    # Chinese sentiment with East Asian cultural context
    positive_keywords = [
      # Chinese positives (romanized)
      "heping", "xieyi", "hezuo", "wending", "jinbu", "chenggong",
      "gaijin", "huifu", "tupo", "jiejue", "tuanjie", "fazhan"
    ]
    
    negative_keywords = [
      "zhanzheng", "chongtu", "baoli", "weiji", "gongji", "kongbu",
      "siwang", "pohuai", "bengkui", "shibai", "shuailuo", "hunluan"
    ]
    
    sentiment = calculate_keyword_sentiment(text, positive_keywords, negative_keywords)
    # Adjust for Chinese cultural context - harmony/stability valued highly
    case sentiment do
      s when s > 0 -> s * 1.1  # Boost positive stability news
      s -> s
    end
  end
  
  defp analyze_russian_sentiment(text) do
    text = String.downcase(text)
    
    positive_keywords = [
      # Russian positives (romanized)
      "mir", "soglashenie", "sotrudnichestvo", "stabilnost", "progress", "uspekh",
      "uluchshenie", "vosstanovlenie", "reshenie", "edinstvo", "rost"
    ]
    
    negative_keywords = [
      "voyna", "konflikt", "nasilie", "krizis", "napadenie", "terrorizm",
      "smert", "razrushenie", "krakh", "proval", "upadok", "khaos"
    ]
    
    calculate_keyword_sentiment(text, positive_keywords, negative_keywords)
  end
  
  defp analyze_french_sentiment(text) do
    text = String.downcase(text)
    
    positive_keywords = [
      "paix", "accord", "coopération", "stabilité", "progrès", "succès",
      "amélioration", "récupération", "percée", "résolution", "unité", "croissance",
      "démocratie", "liberté", "droits", "élection", "vote", "transparence"
    ]
    
    negative_keywords = [
      "guerre", "conflit", "violence", "crise", "attaque", "terrorisme", "mort",
      "destruction", "effondrement", "échec", "déclin", "chaos", "désastre",
      "protestation", "émeute", "tension", "dispute", "corruption"
    ]
    
    calculate_keyword_sentiment(text, positive_keywords, negative_keywords)
  end
  
  defp analyze_german_sentiment(text) do
    text = String.downcase(text)
    
    positive_keywords = [
      "frieden", "vereinbarung", "zusammenarbeit", "stabilität", "fortschritt", "erfolg",
      "verbesserung", "erholung", "durchbruch", "lösung", "einheit", "wachstum",
      "demokratie", "freiheit", "rechte", "wahl", "abstimmung", "transparenz"
    ]
    
    negative_keywords = [
      "krieg", "konflikt", "gewalt", "krise", "angriff", "terrorismus", "tod",
      "zerstörung", "zusammenbruch", "versagen", "rückgang", "chaos", "katastrophe",
      "protest", "aufruhr", "spannung", "streit", "korruption"
    ]
    
    calculate_keyword_sentiment(text, positive_keywords, negative_keywords)
  end
  
  defp analyze_universal_sentiment(text) do
    # Fallback using emotional indicators that work across languages
    text = String.downcase(text)
    
    # Look for emotional punctuation and universal concepts
    positive_indicators = [
      "!", ":)", "✓", "✅", "+", "good", "great", "best", "win", "success"
    ]
    
    negative_indicators = [
      "!!", ":(", "✗", "❌", "-", "bad", "worst", "lose", "fail", "crisis"
    ]
    
    calculate_keyword_sentiment(text, positive_indicators, negative_indicators)
  end
  
  # ============================================================================
  # LANGUAGE DETECTION
  # ============================================================================
  
  defp detect_language(text) do
    text = String.downcase(text)
    
    # Count matches for each language
    language_scores = @language_patterns
    |> Enum.map(fn {lang, patterns} ->
      matches = Enum.count(patterns, fn pattern ->
        String.contains?(text, pattern)
      end)
      {lang, matches}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    
    case language_scores do
      # Require at least 3 matches and be significantly higher than other languages
      [{lang, score} | [{_, second_score} | _]] when score >= 3 and score > second_score + 1 -> 
        lang
      [{lang, score} | []] when score >= 3 -> 
        lang
      _ -> 
        "en"  # Default to English for ambiguous or low-match cases
    end
  end
  
  # ============================================================================
  # GEOGRAPHIC CONTEXT & DIVERSITY BALANCING
  # ============================================================================
  
  defp calculate_balanced_sentiment(analyzed_articles) do
    if length(analyzed_articles) == 0, do: 0.0
    
    # Group by source region for diversity balancing
    regional_groups = analyzed_articles
    |> Enum.group_by(& &1.source_region)
    
    # Calculate sentiment per region, weighted by importance
    regional_sentiments = regional_groups
    |> Enum.map(fn {region, articles} ->
      regional_sentiment = articles
      |> Enum.map(fn a -> a.cultural_sentiment * (a.importance + 0.1) end)
      |> Enum.sum()
      |> Kernel./(Enum.sum(Enum.map(articles, & &1.importance + 0.1)))
      
      {region, regional_sentiment, length(articles)}
    end)
    
    # Balance regions to prevent single-region dominance
    max_weight_per_region = 0.4  # No region can have more than 40% influence
    
    regional_sentiments
    |> Enum.map(fn {region, sentiment, count} ->
      # Calculate weight with diversity constraint
      raw_weight = count / length(analyzed_articles)
      adjusted_weight = min(raw_weight, max_weight_per_region)
      
      {region, sentiment * adjusted_weight, adjusted_weight}
    end)
    |> Enum.map(fn {_, weighted_sentiment, _} -> weighted_sentiment end)
    |> Enum.sum()
  end
  
  defp apply_geographic_context(sentiment, analyzed_articles) do
    # Determine primary regions in the news
    region_distribution = analyzed_articles
    |> Enum.map(& &1.region)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    
    # Apply context based on most represented regions
    case region_distribution do
      [{"middle_east", _} | _] ->
        # Middle East context - adjust baseline expectations
        baseline = @regional_baselines["middle_east"]
        sentiment + baseline.baseline_adjust
        
      [{"africa", _} | _] ->
        # African context
        baseline = @regional_baselines["africa"] 
        sentiment + baseline.baseline_adjust
        
      [{"latin_america", _} | _] ->
        # Latin American context
        baseline = @regional_baselines["latin_america"]
        sentiment + baseline.baseline_adjust
        
      _ ->
        # Default/mixed context
        sentiment
    end
  end
  
  defp apply_historical_baseline(sentiment, _analyzed_articles) do
    # In a full implementation, this would compare against historical averages
    # For now, apply a simple temporal adjustment
    
    current_hour = DateTime.utc_now().hour
    
    # News tends to be more negative during certain hours (early morning, late evening)
    temporal_adjustment = case current_hour do
      h when h in 0..6 -> -0.05   # Early morning - more serious news
      h when h in 7..11 -> 0.05   # Morning - mixed news
      h when h in 12..18 -> 0.0   # Daytime - neutral
      h when h in 19..23 -> -0.02 # Evening - negative bias in news
    end
    
    sentiment + temporal_adjustment
  end
  
  # ============================================================================
  # CULTURAL CONTEXT ADJUSTMENTS  
  # ============================================================================
  
  defp adjust_for_cultural_context(sentiment, language, region) do
    # Cultural adjustments based on language/region combinations
    adjustment = case {language, region} do
      {"ar", "middle_east"} ->
        # Arabic news from Middle East - adjust for different baselines
        cond do
          sentiment > 0.2 -> sentiment * 1.2  # Positive news is especially significant
          sentiment < -0.2 -> sentiment * 0.9  # Negative news is somewhat normalized
          true -> sentiment
        end
        
      {"zh", "asia_pacific"} ->
        # Chinese news - harmony/stability valued highly
        if sentiment > 0, do: sentiment * 1.1, else: sentiment
        
      {"es", "latin_america"} ->
        # Spanish news from Latin America
        sentiment  # Keep neutral for now
        
      _ ->
        sentiment
    end
    
    max(-1.0, min(1.0, adjustment))
  end
  
  # ============================================================================
  # BIAS REPORTING & TRANSPARENCY
  # ============================================================================
  
  defp generate_bias_report(analyzed_articles, raw_sentiment, contextualized_sentiment, final_sentiment) do
    # Language distribution
    language_dist = analyzed_articles
    |> Enum.map(& &1.language) 
    |> Enum.frequencies()
    
    # Regional source distribution  
    source_region_dist = analyzed_articles
    |> Enum.map(& &1.source_region)
    |> Enum.frequencies()
    
    # Content region distribution
    content_region_dist = analyzed_articles  
    |> Enum.map(& &1.region)
    |> Enum.frequencies()
    
    # Sentiment adjustment tracking
    adjustments = %{
      diversity_balancing: contextualized_sentiment - raw_sentiment,
      cultural_context: final_sentiment - contextualized_sentiment,
      total_adjustment: final_sentiment - raw_sentiment
    }
    
    %{
      language_distribution: language_dist,
      source_region_distribution: source_region_dist, 
      content_region_distribution: content_region_dist,
      sentiment_adjustments: adjustments,
      potential_biases: identify_potential_biases(language_dist, source_region_dist, content_region_dist),
      timestamp: DateTime.utc_now()
    }
  end
  
  defp identify_potential_biases(lang_dist, source_dist, content_dist) do
    biases = []
    
    # Safety check for empty distributions
    lang_total = Enum.sum(Map.values(lang_dist))
    source_total = Enum.sum(Map.values(source_dist))
    content_total = Enum.sum(Map.values(content_dist))
    
    # Check for English language dominance
    biases = if lang_total > 0 do
      english_pct = (Map.get(lang_dist, "en", 0) / lang_total) * 100
      if english_pct > 70, do: ["english_language_dominance" | biases], else: biases
    else
      biases
    end
    
    # Check for Western source dominance
    biases = if source_total > 0 do
      western_sources = ["north_america", "europe"]
      western_count = western_sources |> Enum.map(&Map.get(source_dist, &1, 0)) |> Enum.sum()
      western_pct = (western_count / source_total) * 100
      if western_pct > 75, do: ["western_source_bias" | biases], else: biases
    else
      biases
    end
    
    # Check for single region content dominance
    biases = if content_total > 0 do
      max_content_region = content_dist |> Enum.max_by(&elem(&1, 1), fn -> {"none", 0} end)
      {_, max_count} = max_content_region
      content_pct = (max_count / content_total) * 100
      if content_pct > 60, do: ["single_region_focus" | biases], else: biases
    else
      biases
    end
    
    if length(biases) == 0, do: ["balanced_coverage"], else: biases
  end
  
  defp calculate_confidence(analyzed_articles, bias_report) do
    base_confidence = 0.7
    
    # Reduce confidence based on potential biases
    bias_penalty = if "balanced_coverage" in bias_report.potential_biases do
      0.0
    else
      length(bias_report.potential_biases) * 0.1
    end
    
    # Reduce confidence if sample size is small
    sample_penalty = case length(analyzed_articles) do
      n when n < 10 -> 0.3
      n when n < 50 -> 0.2  
      n when n < 100 -> 0.1
      _ -> 0.0
    end
    
    max(0.1, base_confidence - bias_penalty - sample_penalty)
  end
  
  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================
  
  defp calculate_keyword_sentiment(text, positive_keywords, negative_keywords) do
    positive_count = count_keywords(text, positive_keywords)
    negative_count = count_keywords(text, negative_keywords)
    
    total = positive_count + negative_count
    
    cond do
      total == 0 -> 0.0
      negative_count > positive_count -> -0.3 - (negative_count * 0.1) 
      positive_count > negative_count -> 0.3 + (positive_count * 0.1)
      true -> 0.0
    end
    |> max(-1.0)
    |> min(1.0)
  end
  
  defp count_keywords(text, keywords) do
    keywords
    |> Enum.count(&String.contains?(text, String.downcase(&1)))
  end
  
  defp detect_article_region(article) do
    title = Map.get(article, :title, "")
    description = Map.get(article, :description, "")
    text = String.downcase("#{title} #{description}")
    
    # Simple geographic detection (in production, use proper NLP/NER)
    cond do
      contains_any?(text, ["middle east", "syria", "iraq", "iran", "saudi", "israel", "palestine"]) ->
        "middle_east"
      contains_any?(text, ["africa", "nigeria", "kenya", "south africa", "egypt"]) ->
        "africa"  
      contains_any?(text, ["china", "japan", "korea", "india", "asia", "pacific"]) ->
        "asia_pacific"
      contains_any?(text, ["mexico", "brazil", "argentina", "latin america", "south america"]) ->
        "latin_america"
      contains_any?(text, ["europe", "uk", "france", "germany", "italy", "spain"]) ->
        "europe"
      contains_any?(text, ["usa", "america", "canada", "united states"]) ->
        "north_america"
      true ->
        "unknown"
    end
  end
  
  defp contains_any?(text, keywords) when is_list(keywords) do
    Enum.any?(keywords, &String.contains?(text, &1))
  end
end