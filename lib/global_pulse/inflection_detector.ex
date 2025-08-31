defmodule GlobalPulse.InflectionDetector do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    if Process.whereis(GlobalPulse.PubSub) do
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "financial_data")
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "political_data")
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "natural_events")
    end
    
    schedule_detection()
    {:ok, %{data_buffer: [], inflection_points: []}}
  end

  def handle_info({:update, data}, state) do
    new_buffer = [%{data: data, timestamp: DateTime.utc_now()} | state.data_buffer]
    |> Enum.take(100)
    
    {:noreply, %{state | data_buffer: new_buffer}}
  end

  def handle_info(:detect_inflections, state) do
    inflections = detect_inflection_points(state.data_buffer)
    
    if length(inflections) > 0 do
      Logger.info("Detected #{length(inflections)} inflection points")
      Phoenix.PubSub.broadcast(
        GlobalPulse.PubSub,
        "inflection_points",
        {:new_inflections, inflections}
      )
    end
    
    schedule_detection()
    {:noreply, %{state | inflection_points: inflections}}
  end

  defp detect_inflection_points(data_buffer) when length(data_buffer) < 3 do
    []
  end

  defp detect_inflection_points(data_buffer) do
    []
  end

  defp schedule_detection do
    Process.send_after(self(), :detect_inflections, 60_000)
  end
end