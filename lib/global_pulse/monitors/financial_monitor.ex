defmodule GlobalPulse.FinancialMonitor do
  use GenServer
  require Logger

  @poll_interval 60_000
  @crypto_ws_url "wss://stream.binance.com:9443/ws"
  
  defmodule State do
    defstruct [
      :stocks,
      :crypto,
      :forex,
      :commodities,
      :last_update,
      :websocket_pid,
      :anomalies
    ]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    schedule_poll()
    # {:ok, ws_pid} = connect_crypto_websocket()
    
    state = %State{
      stocks: %{
        "SPY" => %{price: 431.23, change_24h: 2.15, change_percent_24h: 0.5, volume: 45623000},
        "QQQ" => %{price: 367.89, change_24h: -1.34, change_percent_24h: -0.36, volume: 32415000},
        "IWM" => %{price: 193.45, change_24h: 0.87, change_percent_24h: 0.45, volume: 28756000}
      },
      crypto: %{
        "BTC" => %{price: 63248.50, change_24h: 1250.30, change_percent_24h: 2.02, volume: 15432000},
        "ETH" => %{price: 2634.75, change_24h: -45.20, change_percent_24h: -1.69, volume: 8765000},
        "ADA" => %{price: 0.4521, change_24h: 0.0134, change_percent_24h: 3.05, volume: 234500000}
      },
      forex: %{
        "EURUSD" => %{price: 1.0876, change_24h: 0.0023, change_percent_24h: 0.21, volume: 0},
        "GBPUSD" => %{price: 1.2634, change_24h: -0.0045, change_percent_24h: -0.35, volume: 0},
        "USDJPY" => %{price: 149.23, change_24h: 0.87, change_percent_24h: 0.58, volume: 0}
      },
      commodities: %{
        "GOLD" => %{price: 2023.45, change_24h: 12.30, change_percent_24h: 0.61, volume: 0},
        "OIL" => %{price: 87.65, change_24h: -1.23, change_percent_24h: -1.38, volume: 0},
        "SILVER" => %{price: 24.87, change_24h: 0.45, change_percent_24h: 1.84, volume: 0}
      },
      websocket_pid: nil,
      anomalies: []
    }
    
    {:ok, state}
  end

  def get_latest_data do
    GenServer.call(__MODULE__, :get_data)
  end

  def get_anomalies do
    GenServer.call(__MODULE__, :get_anomalies)
  end

  def handle_call(:get_data, _from, state) do
    data = %{
      stocks: state.stocks,
      crypto: state.crypto,
      forex: state.forex,
      commodities: state.commodities,
      last_update: state.last_update
    }
    {:reply, data, state}
  end

  def handle_call(:get_anomalies, _from, state) do
    {:reply, state.anomalies, state}
  end

  def handle_info(:poll, state) do
    new_state = 
      state
      |> fetch_stock_data()
      |> fetch_forex_data()
      |> fetch_commodity_data()
      |> detect_anomalies()
      |> broadcast_updates()
    
    schedule_poll()
    {:noreply, new_state}
  end

  def handle_info({:crypto_update, data}, state) do
    new_crypto = Map.merge(state.crypto, parse_crypto_data(data))
    new_state = %{state | crypto: new_crypto}
    |> detect_anomalies()
    |> broadcast_updates()
    
    {:noreply, new_state}
  end

  defp connect_crypto_websocket do
    symbols = ["btcusdt", "ethusdt", "bnbusdt", "adausdt", "dogeusdt"]
    streams = Enum.map(symbols, &"#{&1}@ticker")
    url = "#{@crypto_ws_url}/#{Enum.join(streams, "/")}"
    
    WebSockex.start_link(url, __MODULE__.WebSocketClient, self())
  end

  defp fetch_stock_data(state) do
    case fetch_alpha_vantage_data() do
      {:ok, stock_data} ->
        %{state | stocks: stock_data, last_update: DateTime.utc_now()}
      {:error, _reason} ->
        state
    end
  end

  defp fetch_forex_data(state) do
    case fetch_forex_api_data() do
      {:ok, forex_data} ->
        %{state | forex: forex_data}
      {:error, _reason} ->
        state
    end
  end

  defp fetch_commodity_data(state) do
    commodities = %{
      gold: fetch_commodity_price("gold"),
      silver: fetch_commodity_price("silver"),
      oil: fetch_commodity_price("oil"),
      gas: fetch_commodity_price("gas")
    }
    %{state | commodities: commodities}
  end

  defp fetch_alpha_vantage_data do
    symbols = ["SPY", "QQQ", "DIA", "VIX", "GLD", "TLT"]
    api_key = System.get_env("ALPHA_VANTAGE_API_KEY", "demo")
    
    data = Enum.reduce(symbols, %{}, fn symbol, acc ->
      url = "https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=#{symbol}&apikey=#{api_key}"
      
      case HTTPoison.get(url) do
        {:ok, %{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"Global Quote" => quote}} ->
              Map.put(acc, symbol, parse_stock_quote(quote))
            _ ->
              acc
          end
        _ ->
          acc
      end
    end)
    
    {:ok, data}
  end

  defp fetch_forex_api_data do
    pairs = ["EUR/USD", "GBP/USD", "USD/JPY", "USD/CHF", "AUD/USD"]
    
    data = Enum.reduce(pairs, %{}, fn pair, acc ->
      Map.put(acc, pair, %{
        rate: :rand.uniform() * 2,
        change: :rand.uniform() * 0.05 - 0.025
      })
    end)
    
    {:ok, data}
  end

  defp fetch_commodity_price(commodity) do
    %{
      price: :rand.uniform() * 1000,
      change: :rand.uniform() * 0.1 - 0.05,
      volume: :rand.uniform(100_000)
    }
  end

  defp parse_stock_quote(quote) do
    %{
      symbol: quote["01. symbol"],
      price: String.to_float(quote["05. price"] || "0"),
      change: String.to_float(quote["09. change"] || "0"),
      change_percent: quote["10. change percent"],
      volume: String.to_integer(quote["06. volume"] || "0"),
      timestamp: quote["07. latest trading day"]
    }
  end

  defp parse_crypto_data(data) do
    case Jason.decode(data) do
      {:ok, ticker} ->
        symbol = String.upcase(ticker["s"])
        %{
          symbol => %{
            price: String.to_float(ticker["c"]),
            change_24h: String.to_float(ticker["p"]),
            change_percent_24h: String.to_float(ticker["P"]),
            volume: String.to_float(ticker["v"]),
            high_24h: String.to_float(ticker["h"]),
            low_24h: String.to_float(ticker["l"])
          }
        }
      _ ->
        %{}
    end
  end

  defp detect_anomalies(state) do
    anomalies = []
    
    anomalies = anomalies ++ detect_price_anomalies(state.stocks, "stocks")
    anomalies = anomalies ++ detect_price_anomalies(state.crypto, "crypto")
    anomalies = anomalies ++ detect_volume_spikes(state.stocks)
    anomalies = anomalies ++ detect_correlation_breaks(state)
    
    if length(anomalies) > 0 do
      Logger.warning("Detected #{length(anomalies)} anomalies in financial data")
      Phoenix.PubSub.broadcast(GlobalPulse.PubSub, "anomalies", {:new_anomalies, anomalies})
    end
    
    %{state | anomalies: anomalies}
  end

  defp detect_price_anomalies(data, category) do
    threshold = 0.05
    
    Enum.flat_map(data, fn {symbol, info} ->
      case info do
        %{change_percent_24h: change} when abs(change) > threshold ->
          [%{
            type: :price_anomaly,
            category: category,
            symbol: symbol,
            change: change,
            severity: calculate_severity(change),
            timestamp: DateTime.utc_now()
          }]
        _ ->
          []
      end
    end)
  end

  defp detect_volume_spikes(stocks) do
    Enum.flat_map(stocks, fn {symbol, info} ->
      case info do
        %{volume: volume} when volume > 100_000_000 ->
          [%{
            type: :volume_spike,
            symbol: symbol,
            volume: volume,
            severity: :high,
            timestamp: DateTime.utc_now()
          }]
        _ ->
          []
      end
    end)
  end

  defp detect_correlation_breaks(state) do
    []
  end

  defp calculate_severity(change) do
    cond do
      abs(change) > 0.15 -> :critical
      abs(change) > 0.10 -> :high
      abs(change) > 0.05 -> :medium
      true -> :low
    end
  end

  defp broadcast_updates(state) do
    Phoenix.PubSub.broadcast(
      GlobalPulse.PubSub,
      "financial_data",
      {:update, %{
        stocks: state.stocks,
        crypto: state.crypto,
        forex: state.forex,
        commodities: state.commodities,
        timestamp: DateTime.utc_now()
      }}
    )
    
    # Calculate and update market stress gauge
    update_market_stress_gauge(state)
    
    state
  end
  
  defp update_market_stress_gauge(state) do
    # Calculate market stress from financial indicators
    market_stress = calculate_market_stress_from_state(state)
    
    # Update the gauge data manager
    GlobalPulse.Services.GaugeDataManager.update_value(
      :financial,
      market_stress,
      %{
        crypto_volatility: calculate_crypto_volatility(state.crypto),
        stock_momentum: calculate_stock_momentum(state.stocks),
        anomaly_count: length(state.anomalies || []),
        timestamp: DateTime.utc_now(),
        source: :financial_monitor
      }
    )
  end
  
  defp calculate_market_stress_from_state(state) do
    # Calculate stress based on price changes and anomalies
    crypto_stress = calculate_crypto_stress(state.crypto)
    stock_stress = calculate_stock_stress(state.stocks)
    anomaly_stress = min(length(state.anomalies || []) * 5, 20)
    
    # Weighted average
    stress = (crypto_stress * 0.4) + (stock_stress * 0.4) + (anomaly_stress * 0.2)
    
    # Normalize to 0-100 range
    stress
    |> max(0.0)
    |> min(100.0)
  end
  
  defp calculate_crypto_volatility(crypto) do
    if map_size(crypto) > 0 do
      changes = crypto
        |> Enum.map(fn {_, data} -> abs(data[:change_percent_24h] || 0) end)
      
      Enum.sum(changes) / map_size(crypto)
    else
      0.0
    end
  end
  
  defp calculate_stock_momentum(stocks) do
    if map_size(stocks) > 0 do
      momentum = stocks
        |> Enum.map(fn {_, data} -> data[:change_percent_24h] || 0 end)
        |> Enum.sum()
      
      momentum / map_size(stocks)
    else
      0.0
    end
  end
  
  defp calculate_crypto_stress(crypto) do
    if map_size(crypto) > 0 do
      # High negative changes = high stress
      negative_changes = crypto
        |> Enum.filter(fn {_, data} -> (data[:change_percent_24h] || 0) < 0 end)
        |> Enum.map(fn {_, data} -> abs(data[:change_percent_24h]) end)
      
      if length(negative_changes) > 0 do
        avg_negative = Enum.sum(negative_changes) / length(negative_changes)
        # Scale to 0-100: -10% change = 100 stress
        min(avg_negative * 10, 100)
      else
        0.0
      end
    else
      50.0
    end
  end
  
  defp calculate_stock_stress(stocks) do
    if map_size(stocks) > 0 do
      # Similar calculation for stocks
      negative_changes = stocks
        |> Enum.filter(fn {_, data} -> (data[:change_percent_24h] || 0) < 0 end)
        |> Enum.map(fn {_, data} -> abs(data[:change_percent_24h]) end)
      
      if length(negative_changes) > 0 do
        avg_negative = Enum.sum(negative_changes) / length(negative_changes)
        # Scale to 0-100: -5% change = 100 stress (stocks are less volatile)
        min(avg_negative * 20, 100)
      else
        0.0
      end
    else
      50.0
    end
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end

  defmodule WebSocketClient do
    use WebSockex

    def handle_frame({:text, msg}, parent_pid) do
      send(parent_pid, {:crypto_update, msg})
      {:ok, parent_pid}
    end

    def handle_frame(_frame, state) do
      {:ok, state}
    end
  end
end