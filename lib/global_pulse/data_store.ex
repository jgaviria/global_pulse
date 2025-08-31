defmodule GlobalPulse.DataStore do
  use GenServer
  require Logger

  @table_name :global_pulse_data
  @max_history_size 10000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :ets.new(@table_name, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end

  def store(category, key, value) do
    timestamp = DateTime.utc_now()
    data = %{value: value, timestamp: timestamp}
    
    case :ets.lookup(@table_name, {category, key}) do
      [] ->
        :ets.insert(@table_name, {{category, key}, [data]})
      [{_, history}] ->
        new_history = [data | history] |> Enum.take(@max_history_size)
        :ets.insert(@table_name, {{category, key}, new_history})
    end
  end

  def get_latest(category, key) do
    case :ets.lookup(@table_name, {category, key}) do
      [{_, [latest | _]}] -> {:ok, latest}
      _ -> {:error, :not_found}
    end
  end

  def get_history(category, key, limit \\ 100) do
    case :ets.lookup(@table_name, {category, key}) do
      [{_, history}] -> {:ok, Enum.take(history, limit)}
      _ -> {:ok, []}
    end
  end

  def get_time_series(category, key, start_time, end_time) do
    case :ets.lookup(@table_name, {category, key}) do
      [{_, history}] ->
        filtered = Enum.filter(history, fn %{timestamp: ts} ->
          DateTime.compare(ts, start_time) != :lt &&
          DateTime.compare(ts, end_time) != :gt
        end)
        {:ok, filtered}
      _ ->
        {:ok, []}
    end
  end
end