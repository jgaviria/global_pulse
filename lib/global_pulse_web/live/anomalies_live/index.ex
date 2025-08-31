defmodule GlobalPulseWeb.AnomaliesLive.Index do
  use GlobalPulseWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "anomalies")
    end

    {:ok,
     socket
     |> assign(:page_title, "Anomaly Detection")
     |> assign(:active_tab, :anomalies)
     |> assign(:last_update, DateTime.utc_now())
     |> assign(:anomaly_count, 0)
     |> assign(:anomalies, [])
     |> assign(:filter_severity, "all")
     |> assign(:filter_type, "all")}
  end

  @impl true
  def handle_info({:new_anomalies, anomalies}, socket) do
    all_anomalies = anomalies ++ socket.assigns.anomalies
    |> Enum.uniq_by(&(&1[:timestamp]))
    |> Enum.sort_by(&(&1[:timestamp]), {:desc, DateTime})
    |> Enum.take(100)
    
    {:noreply, 
     socket
     |> assign(:anomalies, all_anomalies)
     |> assign(:anomaly_count, length(all_anomalies))
     |> assign(:last_update, DateTime.utc_now())}
  end

  @impl true
  def handle_event("filter-severity", %{"severity" => severity}, socket) do
    {:noreply, assign(socket, :filter_severity, severity)}
  end

  def handle_event("filter-type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :filter_type, type)}
  end

  def handle_event("clear-anomalies", _, socket) do
    {:noreply, assign(socket, :anomalies, [])}
  end

  defp filtered_anomalies(anomalies, severity_filter, type_filter) do
    anomalies
    |> filter_by_severity(severity_filter)
    |> filter_by_type(type_filter)
  end

  defp filter_by_severity(anomalies, "all"), do: anomalies
  defp filter_by_severity(anomalies, severity) do
    Enum.filter(anomalies, &(to_string(&1[:severity]) == severity))
  end

  defp filter_by_type(anomalies, "all"), do: anomalies
  defp filter_by_type(anomalies, type) do
    Enum.filter(anomalies, &(String.contains?(to_string(&1[:type]), type)))
  end

  defp format_time(nil), do: "Never"
  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S UTC")
  end
end