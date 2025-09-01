defmodule GlobalPulseWeb.SentimentTransparencyLive do
  @moduledoc """
  LiveView component for displaying sentiment analysis bias transparency.
  Shows language distribution, source diversity, potential biases, and confidence levels.
  """
  use GlobalPulseWeb, :live_component
  
  def mount(socket) do
    {:ok, 
     socket
     |> assign(:show_details, false)
    }
  end
  
  def update(assigns, socket) do
    bias_report = get_latest_bias_report()
    
    {:ok, 
     socket
     |> assign(assigns)
     |> assign(:bias_report, bias_report)
    }
  end
  
  def handle_info({:news_update, _data}, socket) do
    # Refresh bias report when news updates
    bias_report = get_latest_bias_report()
    {:noreply, assign(socket, :bias_report, bias_report)}
  end
  
  def handle_event("toggle_details", _params, socket) do
    {:noreply, assign(socket, :show_details, !socket.assigns.show_details)}
  end
  
  defp get_latest_bias_report do
    # Try to get the latest bias report from the NewsMonitor process state
    case GenServer.whereis(GlobalPulse.NewsMonitor) do
      pid when is_pid(pid) ->
        # Get bias report from NewsMonitor state
        case :sys.get_state(pid) do
          %{bias_report: bias_report} when not is_nil(bias_report) ->
            bias_report
          _ ->
            generate_placeholder_report()
        end
      _ ->
        generate_placeholder_report()
    end
  rescue
    _ -> generate_placeholder_report()
  end
  
  defp generate_placeholder_report do
    %{
      language_distribution: %{"en" => 0},
      source_region_distribution: %{"unknown" => 0},
      content_region_distribution: %{"unknown" => 0},
      sentiment_adjustments: %{
        diversity_balancing: 0.0,
        cultural_context: 0.0,
        total_adjustment: 0.0
      },
      potential_biases: ["insufficient_data"],
      timestamp: DateTime.utc_now()
    }
  end
  
  def render(assigns) do
    ~H"""
    <div class="bg-gray-900 rounded-lg p-6 border border-gray-700">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-lg font-semibold text-white">Sentiment Analysis Transparency</h3>
        <button 
          phx-click="toggle_details"
          phx-target={@myself}
          class="text-blue-400 hover:text-blue-300 text-sm"
        >
          <%= if @show_details, do: "Hide Details", else: "Show Details" %>
        </button>
      </div>
      
      <!-- Bias Status Overview -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
        <div class="bg-gray-800 rounded p-3">
          <div class="flex items-center space-x-2">
            <div class={["w-3 h-3 rounded-full", bias_status_color(@bias_report.potential_biases)]}></div>
            <span class="text-sm text-gray-300">Bias Status</span>
          </div>
          <p class="text-lg font-semibold text-white mt-1">
            <%= bias_status_text(@bias_report.potential_biases) %>
          </p>
        </div>
        
        <div class="bg-gray-800 rounded p-3">
          <span class="text-sm text-gray-300">Languages Detected</span>
          <p class="text-lg font-semibold text-white">
            <%= Map.keys(@bias_report.language_distribution) |> length() %>
          </p>
        </div>
        
        <div class="bg-gray-800 rounded p-3">
          <span class="text-sm text-gray-300">Source Regions</span>
          <p class="text-lg font-semibold text-white">
            <%= Map.keys(@bias_report.source_region_distribution) |> length() %>
          </p>
        </div>
      </div>
      
      <%= if @show_details do %>
        <!-- Detailed Bias Analysis -->
        <div class="space-y-4">
          
          <!-- Language Distribution -->
          <div class="bg-gray-800 rounded p-4">
            <h4 class="text-sm font-medium text-gray-300 mb-3">Language Distribution</h4>
            <div class="space-y-2">
              <%= for {lang, count} <- @bias_report.language_distribution |> Enum.sort_by(&elem(&1, 1), :desc) do %>
                <div class="flex items-center justify-between">
                  <span class="text-sm text-gray-400"><%= language_name(lang) %></span>
                  <div class="flex items-center space-x-2">
                    <div class="w-20 bg-gray-700 rounded-full h-2">
                      <div 
                        class="bg-blue-500 h-2 rounded-full transition-all duration-300"
                        style={"width: #{percentage(count, @bias_report.language_distribution)}%"}
                      ></div>
                    </div>
                    <span class="text-sm text-white w-8 text-right"><%= count %></span>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
          
          <!-- Source Region Distribution -->
          <div class="bg-gray-800 rounded p-4">
            <h4 class="text-sm font-medium text-gray-300 mb-3">Source Region Distribution</h4>
            <div class="space-y-2">
              <%= for {region, count} <- @bias_report.source_region_distribution |> Enum.sort_by(&elem(&1, 1), :desc) do %>
                <div class="flex items-center justify-between">
                  <span class="text-sm text-gray-400"><%= region_name(region) %></span>
                  <div class="flex items-center space-x-2">
                    <div class="w-20 bg-gray-700 rounded-full h-2">
                      <div 
                        class="bg-green-500 h-2 rounded-full transition-all duration-300"
                        style={"width: #{percentage(count, @bias_report.source_region_distribution)}%"}
                      ></div>
                    </div>
                    <span class="text-sm text-white w-8 text-right"><%= count %></span>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
          
          <!-- Content Geographic Focus -->
          <div class="bg-gray-800 rounded p-4">
            <h4 class="text-sm font-medium text-gray-300 mb-3">Content Geographic Focus</h4>
            <div class="space-y-2">
              <%= for {region, count} <- @bias_report.content_region_distribution |> Enum.sort_by(&elem(&1, 1), :desc) do %>
                <div class="flex items-center justify-between">
                  <span class="text-sm text-gray-400"><%= region_name(region) %></span>
                  <div class="flex items-center space-x-2">
                    <div class="w-20 bg-gray-700 rounded-full h-2">
                      <div 
                        class="bg-purple-500 h-2 rounded-full transition-all duration-300"
                        style={"width: #{percentage(count, @bias_report.content_region_distribution)}%"}
                      ></div>
                    </div>
                    <span class="text-sm text-white w-8 text-right"><%= count %></span>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
          
          <!-- Sentiment Adjustments -->
          <div class="bg-gray-800 rounded p-4">
            <h4 class="text-sm font-medium text-gray-300 mb-3">Bias Adjustments Applied</h4>
            <div class="space-y-2">
              <div class="flex items-center justify-between">
                <span class="text-sm text-gray-400">Diversity Balancing</span>
                <span class={["text-sm font-mono", adjustment_color(@bias_report.sentiment_adjustments.diversity_balancing)]}>
                  <%= format_adjustment(@bias_report.sentiment_adjustments.diversity_balancing) %>
                </span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-sm text-gray-400">Cultural Context</span>
                <span class={["text-sm font-mono", adjustment_color(@bias_report.sentiment_adjustments.cultural_context)]}>
                  <%= format_adjustment(@bias_report.sentiment_adjustments.cultural_context) %>
                </span>
              </div>
              <div class="flex items-center justify-between border-t border-gray-700 pt-2">
                <span class="text-sm text-white font-medium">Total Adjustment</span>
                <span class={["text-sm font-mono font-medium", adjustment_color(@bias_report.sentiment_adjustments.total_adjustment)]}>
                  <%= format_adjustment(@bias_report.sentiment_adjustments.total_adjustment) %>
                </span>
              </div>
            </div>
          </div>
          
          <!-- Potential Biases -->
          <div class="bg-gray-800 rounded p-4">
            <h4 class="text-sm font-medium text-gray-300 mb-3">Potential Biases Detected</h4>
            <div class="flex flex-wrap gap-2">
              <%= for bias <- @bias_report.potential_biases do %>
                <span class={["px-2 py-1 rounded text-xs font-medium", bias_tag_color(bias)]}>
                  <%= bias_description(bias) %>
                </span>
              <% end %>
            </div>
          </div>
          
          <!-- Methodology Note -->
          <div class="bg-blue-900/20 border border-blue-700/30 rounded p-4">
            <div class="flex items-start space-x-3">
              <div class="text-blue-400 mt-1">
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>
                </svg>
              </div>
              <div>
                <h5 class="text-sm font-medium text-blue-400 mb-1">Methodology Transparency</h5>
                <p class="text-xs text-blue-200 leading-relaxed">
                  This sentiment analysis uses multi-lingual keyword analysis, geographic context weighting, 
                  and source diversity balancing to minimize cultural and linguistic biases. 
                  Adjustments are applied based on regional baselines and historical context.
                  No single source region can dominate more than 40% of the overall sentiment calculation.
                </p>
              </div>
            </div>
          </div>
          
          <!-- Last Updated -->
          <div class="text-right">
            <span class="text-xs text-gray-500">
              Last updated: <%= format_timestamp(@bias_report.timestamp) %>
            </span>
          </div>
          
        </div>
      <% end %>
    </div>
    """
  end
  
  # Helper functions
  
  defp bias_status_color(biases) do
    cond do
      "balanced_coverage" in biases -> "bg-green-500"
      length(biases) <= 1 -> "bg-yellow-500" 
      length(biases) <= 2 -> "bg-orange-500"
      true -> "bg-red-500"
    end
  end
  
  defp bias_status_text(biases) do
    cond do
      "balanced_coverage" in biases -> "Balanced"
      length(biases) <= 1 -> "Minor Bias"
      length(biases) <= 2 -> "Moderate Bias"
      true -> "High Bias"
    end
  end
  
  defp language_name(code) do
    case code do
      "en" -> "English"
      "es" -> "Spanish"
      "fr" -> "French"
      "ar" -> "Arabic"
      "zh" -> "Chinese"
      "ru" -> "Russian"
      "pt" -> "Portuguese"
      "de" -> "German"
      "ja" -> "Japanese"
      "hi" -> "Hindi"
      _ -> String.upcase(code)
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
      _ -> String.replace(region, "_", " ") |> String.capitalize()
    end
  end
  
  defp percentage(count, distribution) do
    total = Map.values(distribution) |> Enum.sum()
    if total > 0, do: round(count / total * 100), else: 0
  end
  
  defp format_adjustment(value) do
    formatted = Float.round(value, 3)
    if formatted >= 0, do: "+#{formatted}", else: "#{formatted}"
  end
  
  defp adjustment_color(value) do
    cond do
      value > 0.05 -> "text-green-400"
      value < -0.05 -> "text-red-400"  
      true -> "text-gray-400"
    end
  end
  
  defp bias_tag_color(bias) do
    case bias do
      "balanced_coverage" -> "bg-green-700 text-green-200"
      "insufficient_data" -> "bg-gray-700 text-gray-300"
      _ -> "bg-orange-700 text-orange-200"
    end
  end
  
  defp bias_description(bias) do
    case bias do
      "balanced_coverage" -> "Balanced Coverage"
      "english_language_dominance" -> "English Dominance"
      "western_source_bias" -> "Western Sources"
      "single_region_focus" -> "Regional Focus"
      "insufficient_data" -> "Insufficient Data"
      _ -> String.replace(bias, "_", " ") |> String.capitalize()
    end
  end
  
  defp format_timestamp(timestamp) do
    Calendar.strftime(timestamp, "%Y-%m-%d %H:%M UTC")
  end
end