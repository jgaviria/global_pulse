defmodule GlobalPulseWeb.FinancialLive.Index do
  use GlobalPulseWeb, :live_view
  
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "financial_data")
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "anomalies")
      
      :timer.send_interval(5000, self(), :fetch_data)
    end
    
    initial_data = fetch_financial_data()
    
    {:ok,
     socket
     |> assign(:page_title, "Financial Markets")
     |> assign(:active_tab, :financial)
     |> assign(:last_update, DateTime.utc_now())
     |> assign(:anomaly_count, 0)
     |> assign(:stocks, initial_data.stocks)
     |> assign(:crypto, initial_data.crypto)
     |> assign(:forex, initial_data.forex)
     |> assign(:commodities, initial_data.commodities)
     |> assign(:chart_data, prepare_chart_data(initial_data))
     |> assign(:selected_asset, "BTC")
     |> assign(:time_range, "1D")
     |> assign(:market_indicators, calculate_market_indicators(initial_data))
     |> assign(:top_gainers, [])
     |> assign(:top_losers, [])}
  end
  
  @impl true
  def handle_info(:fetch_data, socket) do
    data = fetch_financial_data()
    
    {:noreply,
     socket
     |> assign(:stocks, data.stocks)
     |> assign(:crypto, data.crypto)
     |> assign(:forex, data.forex)
     |> assign(:commodities, data.commodities)
     |> assign(:chart_data, prepare_chart_data(data))
     |> assign(:market_indicators, calculate_market_indicators(data))
     |> push_event("update-charts", %{data: prepare_chart_data(data)})}
  end
  
  def handle_info({:update, data}, socket) do
    {:noreply,
     socket
     |> assign(:stocks, data[:stocks] || socket.assigns.stocks)
     |> assign(:crypto, data[:crypto] || socket.assigns.crypto)
     |> assign(:forex, data[:forex] || socket.assigns.forex)
     |> assign(:commodities, data[:commodities] || socket.assigns.commodities)
     |> assign(:last_update, DateTime.utc_now())
     |> assign(:chart_data, prepare_chart_data(data))
     |> push_event("update-charts", %{data: prepare_chart_data(data)})}
  end
  
  def handle_info({:new_anomalies, anomalies}, socket) do
    financial_anomalies = Enum.filter(anomalies, &(&1[:category] in ["stocks", "crypto", "forex"]))
    {:noreply, assign(socket, :anomaly_count, length(financial_anomalies))}
  end
  
  @impl true
  def handle_event("select-asset", %{"asset" => asset}, socket) do
    {:noreply, 
     socket
     |> assign(:selected_asset, asset)
     |> push_event("highlight-asset", %{asset: asset})}
  end
  
  def handle_event("change-time-range", %{"range" => range}, socket) do
    {:noreply, 
     socket
     |> assign(:time_range, range)
     |> push_event("update-time-range", %{range: range})}
  end
  
  defp fetch_financial_data do
    case GlobalPulse.FinancialMonitor.get_latest_data() do
      data when is_map(data) -> data
      _ -> %{stocks: %{}, crypto: %{}, forex: %{}, commodities: %{}}
    end
  end
  
  defp prepare_chart_data(data) do
    %{
      crypto_prices: prepare_crypto_chart(data[:crypto] || %{}),
      stock_indices: prepare_stock_chart(data[:stocks] || %{}),
      forex_rates: prepare_forex_chart(data[:forex] || %{}),
      commodity_prices: prepare_commodity_chart(data[:commodities] || %{}),
      volume_data: prepare_volume_chart(data)
    }
  end
  
  defp prepare_crypto_chart(crypto) do
    crypto
    |> Enum.map(fn {symbol, data} ->
      %{
        name: symbol,
        price: data[:price] || 0,
        change: data[:change_24h] || 0,
        change_percent: data[:change_percent_24h] || 0,
        volume: data[:volume] || 0
      }
    end)
    |> Enum.sort_by(& &1.volume, :desc)
    |> Enum.take(10)
  end
  
  defp prepare_stock_chart(stocks) do
    stocks
    |> Enum.map(fn {symbol, data} ->
      %{
        name: symbol,
        price: data[:price] || 0,
        change: data[:change] || 0,
        volume: data[:volume] || 0
      }
    end)
  end
  
  defp prepare_forex_chart(forex) do
    forex
    |> Enum.map(fn {pair, data} ->
      %{
        pair: pair,
        rate: data[:rate] || 0,
        change: data[:change] || 0
      }
    end)
  end
  
  defp prepare_commodity_chart(commodities) do
    commodities
    |> Enum.map(fn {name, data} ->
      %{
        name: String.capitalize(to_string(name)),
        price: data[:price] || 0,
        change: data[:change] || 0
      }
    end)
  end
  
  defp prepare_volume_chart(data) do
    all_volumes = 
      (data[:crypto] || %{})
      |> Enum.map(fn {symbol, info} -> {symbol, info[:volume] || 0} end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(5)
    
    %{
      labels: Enum.map(all_volumes, &elem(&1, 0)),
      data: Enum.map(all_volumes, &elem(&1, 1))
    }
  end
  
  defp calculate_market_indicators(data) do
    crypto_sentiment = calculate_crypto_sentiment(data[:crypto] || %{})
    stock_momentum = calculate_stock_momentum(data[:stocks] || %{})
    
    %{
      fear_greed_index: calculate_fear_greed(crypto_sentiment, stock_momentum),
      market_cap_change: calculate_market_cap_change(data),
      volatility_index: calculate_volatility(data),
      correlation_matrix: calculate_correlations(data)
    }
  end
  
  defp calculate_crypto_sentiment(crypto) do
    if map_size(crypto) > 0 do
      total_change = crypto
        |> Enum.map(fn {_, data} -> data[:change_percent_24h] || 0 end)
        |> Enum.sum()
      
      total_change / map_size(crypto)
    else
      0
    end
  end
  
  defp calculate_stock_momentum(stocks) do
    if map_size(stocks) > 0 do
      total_change = stocks
        |> Enum.map(fn {_, data} -> data[:change] || 0 end)
        |> Enum.sum()
      
      total_change / map_size(stocks)
    else
      0
    end
  end
  
  defp calculate_fear_greed(crypto_sentiment, stock_momentum) do
    score = (crypto_sentiment + stock_momentum) * 10 + 50
    
    score
    |> max(0)
    |> min(100)
    |> round()
  end
  
  defp calculate_market_cap_change(_data) do
    :rand.uniform() * 10 - 5
  end
  
  defp calculate_volatility(_data) do
    15 + :rand.uniform() * 35
  end
  
  defp calculate_correlations(_data) do
    %{
      "BTC-ETH" => 0.85,
      "SPY-QQQ" => 0.92,
      "Gold-USD" => -0.45
    }
  end
  
  defp format_price(value) when is_number(value) do
    :erlang.float_to_binary(value * 1.0, [{:decimals, 2}])
  end
  
  defp format_change(value) when is_integer(value) do
    Float.round(value * 1.0, 2)
  end
  defp format_change(value) when is_float(value) do
    Float.round(value, 2)
  end
  
  defp format_time(nil), do: "Never"
  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S UTC")
  end
end