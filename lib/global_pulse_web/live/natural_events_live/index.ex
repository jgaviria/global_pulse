defmodule GlobalPulseWeb.NaturalEventsLive.Index do
  use GlobalPulseWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "natural_events")
      Phoenix.PubSub.subscribe(GlobalPulse.PubSub, "anomalies")
      
      # Refresh natural events data every 3 minutes
      :timer.send_interval(180_000, self(), :fetch_natural_events)
    end

    # Get initial data from the NaturalEventsMonitor
    initial_data = get_initial_natural_events_data()

    {:ok,
     socket
     |> assign(:page_title, "Natural Events")
     |> assign(:active_tab, :natural)
     |> assign(:last_update, DateTime.utc_now())
     |> assign(:anomaly_count, 0)
     |> assign(:earthquakes, initial_data.earthquakes)
     |> assign(:weather_events, initial_data.weather_events)
     |> assign(:hurricanes, initial_data.hurricanes)
     |> assign(:wildfires, initial_data.wildfires)
     |> assign(:space_weather, initial_data.space_weather)
     |> assign(:selected_event_type, "all")}
  end

  @impl true
  def handle_info({:update, data}, socket) do
    {:noreply,
     socket
     |> assign(:earthquakes, data[:earthquakes] || [])
     |> assign(:weather_events, data[:weather] || [])
     |> assign(:hurricanes, data[:hurricanes] || [])
     |> assign(:wildfires, data[:wildfires] || [])
     |> assign(:space_weather, data[:space_weather] || %{})
     |> assign(:last_update, DateTime.utc_now())}
  end

  def handle_info({:new_anomalies, anomalies}, socket) do
    natural_anomalies = Enum.filter(anomalies, &(&1[:type] in [:major_earthquake, :geomagnetic_storm, :active_hurricane]))
    {:noreply, assign(socket, :anomaly_count, length(natural_anomalies))}
  end

  def handle_info(:fetch_natural_events, socket) do
    data = get_initial_natural_events_data()
    
    {:noreply,
     socket
     |> assign(:earthquakes, data.earthquakes)
     |> assign(:weather_events, data.weather_events)
     |> assign(:hurricanes, data.hurricanes)
     |> assign(:wildfires, data.wildfires)
     |> assign(:space_weather, data.space_weather)
     |> assign(:last_update, DateTime.utc_now())}
  end

  @impl true
  def handle_event("filter-events", %{"type" => type}, socket) do
    {:noreply, assign(socket, :selected_event_type, type)}
  end
  
  defp get_initial_natural_events_data do
    case GlobalPulse.NaturalEventsMonitor.get_latest_data() do
      %{earthquakes: earthquakes, weather: weather, hurricanes: hurricanes, wildfires: wildfires, space: space_weather} ->
        %{
          earthquakes: earthquakes || [],
          weather_events: weather || [],
          hurricanes: hurricanes || [],
          wildfires: wildfires || [],
          space_weather: space_weather || %{}
        }
      _ ->
        %{
          earthquakes: [],
          weather_events: [],
          hurricanes: [],
          wildfires: [],
          space_weather: %{}
        }
    end
  rescue
    _ ->
      %{
        earthquakes: [],
        weather_events: [],
        hurricanes: [],
        wildfires: [],
        space_weather: %{}
      }
  end

  defp format_magnitude(magnitude) when is_number(magnitude) do
    magnitude |> :erlang.float() |> Float.round(1)
  end
  defp format_magnitude(_), do: "N/A"

  defp format_decimal(number) when is_number(number) do
    number |> :erlang.float() |> Float.round(1)
  end
  defp format_decimal(_), do: 0

  defp safe_round(number) when is_number(number), do: round(number)
  defp safe_round(_), do: 0

  defp format_temperature(number) when is_number(number) and number >= 1_000_000 do
    formatted = (number / 1_000_000) |> :erlang.float() |> Float.round(1) |> to_string()
    formatted <> "M"
  end
  defp format_temperature(number) when is_number(number) and number >= 1_000 do
    formatted = (number / 1_000) |> :erlang.float() |> Float.round(0) |> to_string()
    formatted <> "K"
  end
  defp format_temperature(number) when is_number(number), do: to_string(round(number))
  defp format_temperature(_), do: "0"

  # Aurora Animation Functions
  defp aurora_animation_class(kp_index, layer) do
    base_class = "bg-gradient-to-r"
    intensity_class = case kp_index do
      kp when kp >= 8 -> "from-red-400 via-purple-400 to-green-400"
      kp when kp >= 6 -> "from-purple-400 via-pink-400 to-green-400" 
      kp when kp >= 4 -> "from-green-400 via-blue-400 to-purple-400"
      kp when kp >= 2 -> "from-green-400 to-blue-400"
      _ -> "from-gray-600 to-gray-500"
    end
    
    animation_class = case {kp_index, layer} do
      {kp, _} when kp >= 8 -> "animate-ping"
      {kp, 1} when kp >= 6 -> "animate-bounce"
      {kp, 2} when kp >= 4 -> "animate-pulse"
      {kp, 3} when kp >= 2 -> "animate-pulse"
      _ -> ""
    end
    
    "#{base_class} #{intensity_class} #{animation_class}"
  end

  defp aurora_size_class(kp_index, layer) do
    base_size = case layer do
      1 -> "w-16 h-8"
      2 -> "w-20 h-6" 
      3 -> "w-24 h-4"
      _ -> "w-12 h-6"
    end
    
    size_multiplier = case kp_index do
      kp when kp >= 8 -> "scale-150"
      kp when kp >= 6 -> "scale-125"
      kp when kp >= 4 -> "scale-110"
      _ -> "scale-100"
    end
    
    "#{base_size} #{size_multiplier}"
  end

  defp aurora_animation_delay(layer) do
    delay = layer * 0.5
    "animation-delay: #{delay}s;"
  end

  # Magnetic Field Functions
  defp magnetic_field_class(kp_index, _line) do
    color = case kp_index do
      kp when kp >= 8 -> "bg-red-400 animate-pulse"
      kp when kp >= 6 -> "bg-purple-400"
      kp when kp >= 4 -> "bg-blue-400"
      _ -> "bg-gray-500"
    end
    
    "w-16 h-0.5 rounded #{color}"
  end

  defp magnetic_field_position(line) do
    left_positions = [20, 35, 50, 65]
    left = Enum.at(left_positions, line - 1, 20)
    "left: #{left}%;"
  end

  # Geomagnetic Indicator Functions
  defp geomagnetic_indicator_class("Extreme"), do: "bg-red-500 animate-pulse"
  defp geomagnetic_indicator_class("Severe"), do: "bg-red-400 animate-bounce"
  defp geomagnetic_indicator_class("Strong"), do: "bg-orange-400 animate-ping"
  defp geomagnetic_indicator_class("Moderate"), do: "bg-yellow-400"
  defp geomagnetic_indicator_class(_), do: "bg-green-400"

  defp severity_background_class("Extreme"), do: "bg-red-500/20 border border-red-500"
  defp severity_background_class("Severe"), do: "bg-red-400/20 border border-red-400"
  defp severity_background_class("Strong"), do: "bg-orange-400/20 border border-orange-400"
  defp severity_background_class("Moderate"), do: "bg-yellow-400/20 border border-yellow-400"
  defp severity_background_class(_), do: "bg-green-400/20 border border-green-400"

  defp kp_color_class(kp) when kp >= 8, do: "text-red-400"
  defp kp_color_class(kp) when kp >= 6, do: "text-orange-400"
  defp kp_color_class(kp) when kp >= 4, do: "text-yellow-400"
  defp kp_color_class(_), do: "text-green-400"

  # Solar Wind Animation Functions
  defp solar_activity_class(speed) do
    base = "bg-gradient-to-br from-yellow-400 to-orange-500"
    activity = case speed do
      s when s >= 800 -> "animate-ping shadow-lg shadow-red-500/50"
      s when s >= 600 -> "animate-pulse shadow-md shadow-orange-500/50"
      s when s >= 400 -> "animate-bounce shadow-sm shadow-yellow-500/30"
      _ -> ""
    end
    
    "#{base} #{activity}"
  end

  defp wind_particle_class(speed, _particle) do
    case speed do
      s when s >= 800 -> "animate-ping"
      s when s >= 600 -> "animate-bounce"  
      s when s >= 400 -> "animate-pulse"
      _ -> "animate-pulse"
    end
  end

  defp wind_particle_delay(particle) do
    delay = particle * 0.2
    "left: #{10 + particle * 8}%; animation-delay: #{delay}s;"
  end

  defp density_particle_class(_particle) do
    "animate-[fly-density_2s_linear_infinite]"
  end

  defp density_particle_delay(particle) do
    delay = particle * 0.3
    "left: #{15 + particle * 10}%; animation-delay: #{delay}s; transform: translateY(#{particle * 3}px);"
  end

  defp wind_speed_indicator_class(speed) do
    case speed do
      s when s >= 800 -> "bg-red-500 animate-ping"
      s when s >= 600 -> "bg-orange-500 animate-pulse"
      s when s >= 400 -> "bg-yellow-500"
      _ -> "bg-green-500"
    end
  end

  defp temperature_glow_class(temp) do
    case temp do
      t when t >= 1_500_000 -> "bg-gradient-to-r from-red-500/10 to-pink-500/10 animate-pulse"
      t when t >= 1_000_000 -> "bg-gradient-to-r from-orange-500/10 to-red-500/10"
      t when t >= 500_000 -> "bg-gradient-to-r from-yellow-500/10 to-orange-500/10"
      _ -> "bg-gradient-to-r from-blue-500/5 to-purple-500/5"
    end
  end

  # Data Color Functions
  defp wind_speed_color_class(speed) do
    case speed do
      s when s >= 800 -> "text-red-400"
      s when s >= 600 -> "text-orange-400" 
      s when s >= 400 -> "text-yellow-400"
      _ -> "text-green-400"
    end
  end

  defp density_color_class(density) do
    case density do
      d when d >= 20 -> "text-red-400"
      d when d >= 15 -> "text-orange-400"
      d when d >= 10 -> "text-yellow-400"
      _ -> "text-blue-400"
    end
  end

  defp temperature_color_class(temp) do
    case temp do
      t when t >= 1_500_000 -> "text-red-400"
      t when t >= 1_000_000 -> "text-orange-400"
      t when t >= 500_000 -> "text-yellow-400"
      _ -> "text-blue-400"
    end
  end

  # Earth Magnetosphere Functions
  defp earth_magnetosphere_class(speed) do
    case speed do
      s when s >= 800 -> "border-red-400 animate-ping scale-125"    # Compressed magnetosphere
      s when s >= 600 -> "border-orange-400 animate-pulse scale-115" # Moderate compression
      s when s >= 400 -> "border-blue-400 animate-pulse scale-105"   # Slight compression
      _ -> "border-blue-300 scale-100"                               # Normal magnetosphere
    end
  end

  # SuperStorm Style Geomagnetic Functions
  defp magnetosphere_field_line_class(kp_index, _line) do
    base = "border-blue-400"
    intensity = case kp_index do
      kp when kp >= 8 -> "border-red-400 animate-pulse opacity-60"
      kp when kp >= 6 -> "border-orange-400 animate-pulse opacity-50"
      kp when kp >= 4 -> "border-blue-400 opacity-40"
      _ -> "border-blue-300 opacity-30"
    end
    
    "#{base} #{intensity}"
  end

  defp magnetosphere_position(line) do
    # Create concentric field lines around Earth
    size = 16 + (line * 8)  # 24px, 32px, 40px, etc.
    offset = size / 2
    "width: #{size}px; height: #{size}px; top: -#{offset - 32}px; left: -#{offset - 32}px;"
  end

  defp aurora_oval_class(kp_index, pole) do
    base_gradient = case pole do
      :north -> "bg-gradient-to-r"
      :south -> "bg-gradient-to-l"
    end
    
    intensity_colors = case kp_index do
      kp when kp >= 8 -> "from-red-500 via-purple-400 to-green-400 animate-ping"
      kp when kp >= 6 -> "from-purple-500 via-pink-400 to-green-400 animate-pulse"
      kp when kp >= 4 -> "from-green-400 via-blue-400 to-purple-400 animate-pulse"
      kp when kp >= 2 -> "from-green-400 to-blue-400"
      _ -> "from-gray-600 to-gray-500"
    end
    
    "#{base_gradient} #{intensity_colors}"
  end

  defp geomagnetic_glow_class(kp_index) do
    case kp_index do
      kp when kp >= 8 -> "shadow-2xl shadow-red-500/50 animate-pulse"
      kp when kp >= 6 -> "shadow-xl shadow-purple-500/40 animate-pulse"
      kp when kp >= 4 -> "shadow-lg shadow-blue-500/30"
      _ -> "shadow-md shadow-blue-300/20"
    end
  end

  defp intensity_scale_position(kp_index) do
    # Map KP index (0-9) to position on scale (0-96px from bottom)
    position = min(96, kp_index * 10)
    "bottom: #{position}px;"
  end

  # 3D SuperStorm Style Functions
  defp grid_line_style(index, direction) do
    case direction do
      :horizontal ->
        y = index * 20
        "top: #{y}px; left: 0; right: 0; height: 1px; border-top: 1px dotted;"
      :vertical ->
        x = index * 30
        "left: #{x}px; top: 0; bottom: 0; width: 1px; border-left: 1px dotted;"
    end
  end

  defp field_line_3d_class(kp_index, line) do
    color = case kp_index do
      kp when kp >= 8 -> "border-red-400 animate-pulse"
      kp when kp >= 6 -> "border-orange-400 animate-pulse"
      kp when kp >= 4 -> "border-blue-400"
      _ -> "border-blue-300"
    end
    
    opacity = case line do
      1 -> "opacity-60"
      2 -> "opacity-50"
      3 -> "opacity-40"
      4 -> "opacity-30"
      5 -> "opacity-20"
      _ -> "opacity-10"
    end
    
    "#{color} #{opacity}"
  end

  defp field_line_3d_position(line) do
    # Create concentric ellipses for 3D effect
    width = 20 + (line * 12)  # Increasing width
    height = 16 + (line * 8)  # Increasing height
    top_offset = -(line * 6)
    left_offset = -(line * 6)
    
    "width: #{width}px; height: #{height}px; top: #{top_offset}px; left: #{left_offset}px;"
  end

  defp aurora_3d_class(kp_index) do
    base = "bg-gradient-to-r"
    colors_and_animation = case kp_index do
      kp when kp >= 8 -> "from-red-500 via-purple-400 to-green-400 animate-ping"
      kp when kp >= 6 -> "from-purple-500 via-pink-400 to-green-400 animate-pulse" 
      kp when kp >= 4 -> "from-green-400 via-blue-400 to-purple-400"
      kp when kp >= 2 -> "from-green-400 to-blue-400"
      _ -> "from-gray-500 to-gray-600"
    end
    
    "#{base} #{colors_and_animation}"
  end

  defp distortion_wave_class(wave) do
    size = case wave do
      1 -> "w-24 h-20"
      2 -> "w-32 h-24" 
      3 -> "w-40 h-28"
      _ -> "w-20 h-16"
    end
    
    "#{size}"
  end

  defp distortion_wave_position(wave) do
    offset = wave * 8
    "top: -#{offset}px; left: -#{offset}px;"
  end

  defp scale_indicator_position(kp_index) do
    # Map KP (0-9) to position on 28-unit scale from bottom
    position = min(112, kp_index * 12)
    "bottom: #{position}px;"
  end

  defp activity_level_badge("Extreme"), do: "bg-red-600 text-white animate-pulse"
  defp activity_level_badge("Severe"), do: "bg-red-500 text-white animate-pulse"
  defp activity_level_badge("Strong"), do: "bg-orange-500 text-white"
  defp activity_level_badge("Moderate"), do: "bg-yellow-500 text-black"
  defp activity_level_badge("Minor"), do: "bg-green-500 text-white"
  defp activity_level_badge(_), do: "bg-gray-500 text-white"

  defp natural_magnitude_color(magnitude) when magnitude >= 7.0, do: "bg-red-600"
  defp natural_magnitude_color(magnitude) when magnitude >= 6.0, do: "bg-red-500"
  defp natural_magnitude_color(magnitude) when magnitude >= 5.0, do: "bg-orange-500"
  defp natural_magnitude_color(_), do: "bg-yellow-500"

  defp natural_earthquake_color(count) when count > 5, do: "text-red-400"
  defp natural_earthquake_color(count) when count > 2, do: "text-orange-400"
  defp natural_earthquake_color(_), do: "text-gray-400"

  defp natural_category_badge(1), do: "bg-yellow-500/20 text-yellow-400"
  defp natural_category_badge(2), do: "bg-orange-500/20 text-orange-400"
  defp natural_category_badge(3), do: "bg-red-500/20 text-red-400"
  defp natural_category_badge(4), do: "bg-red-600/20 text-red-500"
  defp natural_category_badge(5), do: "bg-red-700/20 text-red-600"
  defp natural_category_badge(_), do: "bg-gray-500/20 text-gray-400"

  defp natural_space_weather_class("Extreme"), do: "text-red-400"
  defp natural_space_weather_class("Severe"), do: "text-orange-400"
  defp natural_space_weather_class("Strong"), do: "text-yellow-400"
  defp natural_space_weather_class(_), do: "text-green-400"

  defp natural_format_relative_time(nil), do: "Unknown time"
  defp natural_format_relative_time(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :hour)
    cond do
      diff < 1 -> "< 1h ago"
      diff < 24 -> "#{diff}h ago"
      diff < 168 -> "#{div(diff, 24)}d ago"
      true -> "#{div(diff, 168)}w ago"
    end
  end

  defp format_time(nil), do: "Never"
  defp format_time(datetime) do
    Calendar.strftime(datetime, "%H:%M:%S UTC")
  end

  # SVG Helper Functions for SuperStorm Style
  defp aurora_svg_gradient_stops(kp_index) do
    case kp_index do
      kp when kp >= 8 ->
        """
        <stop offset="0%" stop-color="#DC2626" stop-opacity="0.9"/>
        <stop offset="30%" stop-color="#A855F7" stop-opacity="0.8"/>
        <stop offset="60%" stop-color="#06B6D4" stop-opacity="0.7"/>
        <stop offset="100%" stop-color="#10B981" stop-opacity="0.6"/>
        """
      kp when kp >= 6 ->
        """
        <stop offset="0%" stop-color="#A855F7" stop-opacity="0.8"/>
        <stop offset="40%" stop-color="#EC4899" stop-opacity="0.7"/>
        <stop offset="80%" stop-color="#06B6D4" stop-opacity="0.6"/>
        <stop offset="100%" stop-color="#10B981" stop-opacity="0.5"/>
        """
      kp when kp >= 4 ->
        """
        <stop offset="0%" stop-color="#10B981" stop-opacity="0.7"/>
        <stop offset="50%" stop-color="#3B82F6" stop-opacity="0.6"/>
        <stop offset="100%" stop-color="#A855F7" stop-opacity="0.5"/>
        """
      kp when kp >= 2 ->
        """
        <stop offset="0%" stop-color="#10B981" stop-opacity="0.6"/>
        <stop offset="100%" stop-color="#3B82F6" stop-opacity="0.4"/>
        """
      _ ->
        """
        <stop offset="0%" stop-color="#6B7280" stop-opacity="0.3"/>
        <stop offset="100%" stop-color="#4B5563" stop-opacity="0.2"/>
        """
    end
  end

  defp longitude_line_path(i) do
    # Create curved longitude lines for 3D hemisphere effect
    x_center = 160  # Center of 320px wide viewBox
    radius = 80     # Base radius
    
    # Calculate longitude angle for 11 lines (-75° to +75° in 15° increments)
    lon_angle = (i - 6) * 15  # -75° to +75° in 15° increments
    
    # Convert to radians for calculation
    rad = lon_angle * :math.pi() / 180
    
    # Calculate 3D perspective projection
    sin_lon = :math.sin(rad)
    _cos_lon = :math.cos(rad)
    
    # Calculate start and end points for curved meridian with proper 3D effect
    x_top = x_center + radius * sin_lon * 0.85
    x_mid = x_center + radius * sin_lon * 0.95  # Widest part at equator
    x_bottom = x_center + radius * sin_lon * 0.8
    
    y_top = 96 - 55    # North pole region
    y_mid = 96         # Equator 
    y_bottom = 96 + 50 # South pole region
    
    # Adjust for perspective - central meridians are more visible
    visibility_factor = 1 - abs(sin_lon) * 0.3
    
    x_top = x_top * visibility_factor + x_center * (1 - visibility_factor)
    x_bottom = x_bottom * visibility_factor + x_center * (1 - visibility_factor)
    
    "M #{x_top},#{y_top} Q #{x_mid},#{y_mid} #{x_bottom},#{y_bottom}"
  end

  defp magnetosphere_animation_class(kp_index) do
    case kp_index do
      kp when kp >= 8 -> "animate-ping"
      kp when kp >= 6 -> "animate-pulse"
      kp when kp >= 4 -> "animate-pulse"
      _ -> ""
    end
  end

  defp magnetosphere_color(kp_index) do
    case kp_index do
      kp when kp >= 8 -> "#DC2626"  # red-600
      kp when kp >= 6 -> "#F97316"  # orange-500
      kp when kp >= 4 -> "#3B82F6"  # blue-500
      _ -> "#93C5FD"                # blue-300
    end
  end

  defp aurora_animation_class(kp_index) do
    case kp_index do
      kp when kp >= 8 -> "animate-ping"
      kp when kp >= 6 -> "animate-pulse"
      kp when kp >= 4 -> "animate-pulse"
      _ -> ""
    end
  end

  defp aurora_inner_color(kp_index) do
    case kp_index do
      kp when kp >= 8 -> "#DC2626"  # red-600
      kp when kp >= 6 -> "#A855F7"  # purple-500
      kp when kp >= 4 -> "#10B981"  # emerald-500
      _ -> "#6B7280"                # gray-500
    end
  end

  defp svg_scale_indicator_position(kp_index) do
    # Map KP (0-9) to position on scale from bottom (156px height)
    position = min(140, kp_index * 15)
    144 - position  # Convert to y coordinate from top
  end
  
  # Helper functions for handling no data stream state
  defp get_space_weather_severity(:no_data_stream), do: "No Data Stream"
  defp get_space_weather_severity(space_weather) when is_map(space_weather) do
    get_in(space_weather, [:geomagnetic_storm, :severity]) || "Quiet"
  end
  defp get_space_weather_severity(_), do: "No Data Stream"
  
  defp get_space_weather_kp(:no_data_stream), do: 0
  defp get_space_weather_kp(space_weather) when is_map(space_weather) do
    get_in(space_weather, [:geomagnetic_storm, :kp_index]) || 0
  end
  defp get_space_weather_kp(_), do: 0
  
  defp get_solar_wind_speed(:no_data_stream), do: 0
  defp get_solar_wind_speed(space_weather) when is_map(space_weather) do
    get_in(space_weather, [:solar_wind, :speed]) || 0
  end
  defp get_solar_wind_speed(_), do: 0
  
  defp get_solar_wind_density(:no_data_stream), do: 0
  defp get_solar_wind_density(space_weather) when is_map(space_weather) do
    get_in(space_weather, [:solar_wind, :density]) || 0
  end
  defp get_solar_wind_density(_), do: 0
  
  defp get_solar_wind_temperature(:no_data_stream), do: 0
  defp get_solar_wind_temperature(space_weather) when is_map(space_weather) do
    get_in(space_weather, [:solar_wind, :temperature]) || 0
  end
  defp get_solar_wind_temperature(_), do: 0
  
  defp get_aurora_visibility(:no_data_stream), do: 90
  defp get_aurora_visibility(space_weather) when is_map(space_weather) do
    get_in(space_weather, [:geomagnetic_storm, :aurora_visibility_lat]) || 90
  end
  defp get_aurora_visibility(_), do: 90
  
  defp space_weather_has_data?(:no_data_stream), do: false
  defp space_weather_has_data?(space_weather) when is_map(space_weather), do: map_size(space_weather) > 0
  defp space_weather_has_data?(_), do: false
end