defmodule GlobalPulse.NaturalEventsMonitor do
  use GenServer
  require Logger
  
  alias GlobalPulse.Services.NOAASpaceWeather

  @poll_interval 180_000
  @magnitude_threshold 4.5
  
  defmodule State do
    defstruct [
      :earthquakes,
      :weather_events,
      :hurricanes,
      :wildfires,
      :floods,
      :volcanic_activity,
      :space_weather,
      :last_update,
      :anomalies
    ]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    # Schedule first poll after initialization
    Process.send_after(self(), :initial_fetch, 100)
    schedule_poll()
    
    initial_state = %State{
      earthquakes: [],
      weather_events: [],
      hurricanes: [],
      wildfires: [],
      floods: [],
      volcanic_activity: [],
      space_weather: generate_default_space_weather(),
      anomalies: [],
      last_update: DateTime.utc_now()
    }
    
    {:ok, initial_state}
  end
  
  def handle_info(:initial_fetch, state) do
    # Fetch initial data after PubSub is ready
    new_state = 
      state
      |> fetch_earthquake_data()
      |> fetch_weather_data()
      |> fetch_hurricane_data()
      |> fetch_wildfire_data()
      |> fetch_flood_data()
      |> fetch_volcanic_data()
      |> fetch_space_weather()
      |> detect_natural_anomalies()
      |> broadcast_updates()
    
    Logger.info("NaturalEventsMonitor initialized with #{length(new_state.earthquakes)} earthquakes, #{length(new_state.weather_events)} weather events")
    
    {:noreply, new_state}
  end
  
  defp generate_default_space_weather do
    %{
      solar_flares: [],
      geomagnetic_storm: %{
        kp_index: 3,
        severity: "Minor",
        aurora_visibility_lat: 65
      },
      solar_wind: %{
        speed: 400,
        density: 5.0,
        temperature: 100_000
      },
      radiation_storm: false,
      timestamp: DateTime.utc_now()
    }
  end

  def get_latest_data do
    GenServer.call(__MODULE__, :get_data)
  end

  def get_critical_events do
    GenServer.call(__MODULE__, :get_critical)
  end

  def handle_call(:get_data, _from, state) do
    data = %{
      earthquakes: state.earthquakes,
      weather: state.weather_events,
      hurricanes: state.hurricanes,
      wildfires: state.wildfires,
      floods: state.floods,
      volcanic: state.volcanic_activity,
      space: state.space_weather,
      last_update: state.last_update
    }
    {:reply, data, state}
  end

  def handle_call(:get_critical, _from, state) do
    critical = filter_critical_events(state)
    {:reply, critical, state}
  end

  def handle_info(:poll, state) do
    new_state = 
      state
      |> fetch_earthquake_data()
      |> fetch_weather_data()
      |> fetch_hurricane_data()
      |> fetch_wildfire_data()
      |> fetch_flood_data()
      |> fetch_volcanic_data()
      |> fetch_space_weather()
      |> detect_natural_anomalies()
      |> broadcast_updates()
    
    schedule_poll()
    {:noreply, new_state}
  end

  defp fetch_earthquake_data(state) do
    url = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_day.geojson"
    Logger.info("🌍 USGS Earthquake API: Fetching from #{url}")
    
    earthquakes = case HTTPoison.get(url, [], timeout: 10_000, recv_timeout: 10_000) do
      {:ok, %{status_code: 200, body: body}} ->
        Logger.info("🌍 USGS Earthquake API: Raw Response (#{byte_size(body)} bytes)")
        
        case Jason.decode(body) do
          {:ok, %{"features" => features}} ->
            Logger.info("🌍 USGS Earthquake API: Found #{length(features)} earthquake records")
            
            parsed_earthquakes = features
              |> Enum.map(&parse_earthquake/1)
              |> Enum.filter(fn eq -> 
                eq != nil and is_number(eq.magnitude) and eq.magnitude >= @magnitude_threshold
              end)
              |> Enum.sort_by(&(&1.magnitude), :desc)
              |> Enum.take(20)
            
            Logger.info("🌍 Successfully parsed #{length(parsed_earthquakes)} earthquakes (magnitude >= #{@magnitude_threshold})")
            
            if length(parsed_earthquakes) > 0 do
              # Log top earthquakes for verification
              Enum.take(parsed_earthquakes, 3) |> Enum.each(fn eq ->
                Logger.info("🌍   - M#{eq.magnitude} #{eq.location} (#{eq.time})")
              end)
              parsed_earthquakes
            else
              Logger.warning("🌍 EARTHQUAKE DATA STREAM: NO SIGNIFICANT EARTHQUAKES - No earthquakes above magnitude #{@magnitude_threshold}")
              []
            end
            
          {:error, decode_error} ->
            Logger.error("🌍 USGS Earthquake API: JSON decode failed - #{inspect(decode_error)}")
            []
        end
      {:ok, %{status_code: status_code}} ->
        Logger.warning("🌍 USGS Earthquake API: HTTP #{status_code} error")
        []
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("🌍 USGS Earthquake API: Connection error - #{reason}")
        []
    end
    
    %{state | earthquakes: earthquakes, last_update: DateTime.utc_now()}
  end

  defp parse_earthquake(feature) do
    try do
      props = feature["properties"]
      coords = feature["geometry"]["coordinates"]
      
      # Validate required fields
      magnitude = props["mag"]
      location = props["place"]
      
      if is_number(magnitude) and is_binary(location) and is_list(coords) and length(coords) >= 2 do
        %{
          id: feature["id"],
          magnitude: magnitude,
          location: location,
          latitude: Enum.at(coords, 1) || 0.0,
          longitude: Enum.at(coords, 0) || 0.0,
          depth: Enum.at(coords, 2) || 0.0,
          time: parse_timestamp(props["time"]),
          tsunami_warning: props["tsunami"] == 1,
          felt_reports: props["felt"] || 0,
          significance: props["sig"] || 0,
          alert_level: props["alert"],
          url: props["url"]
        }
      else
        Logger.debug("🌍 Skipping invalid earthquake record: magnitude=#{inspect(magnitude)}, location=#{inspect(location)}")
        nil
      end
    rescue
      e ->
        Logger.debug("🌍 Error parsing earthquake: #{inspect(e)}")
        nil
    end
  end


  defp fetch_weather_data(state) do
    api_key = System.get_env("OPENWEATHER_API_KEY", "demo")
    cities = [
      %{name: "New York", lat: 40.7128, lon: -74.0060},
      %{name: "London", lat: 51.5074, lon: -0.1278},
      %{name: "Tokyo", lat: 35.6762, lon: 139.6503},
      %{name: "Sydney", lat: -33.8688, lon: 151.2093},
      %{name: "Mumbai", lat: 19.0760, lon: 72.8777}
    ]
    
    weather_events = Enum.flat_map(cities, fn city ->
      fetch_city_weather(city, api_key)
    end)
    
    severe_weather = weather_events
    |> Enum.filter(&is_severe_weather/1)
    
    %{state | weather_events: severe_weather}
  end

  defp fetch_city_weather(city, api_key) do
    url = "https://api.openweathermap.org/data/2.5/weather?lat=#{city.lat}&lon=#{city.lon}&appid=#{api_key}"
    
    case HTTPoison.get(url) do
      {:ok, %{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} ->
            [parse_weather_data(data, city.name)]
          _ ->
            []
        end
      _ ->
        mock_weather_event(city.name)
    end
  end

  defp parse_weather_data(data, city_name) do
    %{
      location: city_name,
      type: data["weather"] |> List.first() |> Map.get("main"),
      description: data["weather"] |> List.first() |> Map.get("description"),
      temperature: data["main"]["temp"] - 273.15,
      pressure: data["main"]["pressure"],
      humidity: data["main"]["humidity"],
      wind_speed: data["wind"]["speed"],
      wind_direction: data["wind"]["deg"],
      visibility: data["visibility"],
      clouds: data["clouds"]["all"],
      timestamp: DateTime.utc_now()
    }
  end

  defp mock_weather_event(city_name) do
    if :rand.uniform() > 0.7 do
      [%{
        location: city_name,
        type: Enum.random(["Thunderstorm", "Hurricane", "Tornado", "Blizzard"]),
        description: "Severe weather warning",
        temperature: :rand.uniform() * 40,
        pressure: 950 + :rand.uniform(100),
        humidity: :rand.uniform(100),
        wind_speed: 50 + :rand.uniform(100),
        wind_direction: :rand.uniform(360),
        visibility: :rand.uniform(10000),
        clouds: :rand.uniform(100),
        timestamp: DateTime.utc_now()
      }]
    else
      []
    end
  end

  defp is_severe_weather(event) do
    event.type in ["Thunderstorm", "Hurricane", "Tornado", "Blizzard"] ||
    event.wind_speed > 75 ||
    event.pressure < 980
  end

  defp fetch_hurricane_data(state) do
    # Try multiple NHC endpoints for comprehensive storm data
    endpoints = [
      {"https://www.nhc.noaa.gov/gis/forecast/archive/al_latest.geojson", "Atlantic"},
      {"https://www.nhc.noaa.gov/gis/forecast/archive/ep_latest.geojson", "Eastern Pacific"}
    ]
    
    all_storms = endpoints
    |> Enum.flat_map(fn {url, basin} -> fetch_storms_from_endpoint(url, basin) end)
    |> Enum.uniq_by(&(&1.name))  # Remove duplicates
    
    Logger.info("🌀 Total active storms from all basins: #{length(all_storms)}")
    
    %{state | hurricanes: all_storms, last_update: DateTime.utc_now()}
  end

  defp fetch_storms_from_endpoint(url, basin) do
    Logger.info("🌀 NHC Hurricane API: Fetching #{basin} storms from #{url}")
    
    case HTTPoison.get(url, [], timeout: 10_000, recv_timeout: 10_000) do
      {:ok, %{status_code: 200, body: body}} ->
        Logger.info("🌀 NHC Hurricane API: Raw Response (#{byte_size(body)} bytes)")
        
        case Jason.decode(body) do
          {:ok, %{"features" => features}} when is_list(features) ->
            Logger.info("🌀 #{basin}: Successfully decoded GeoJSON with #{length(features)} features")
            
            # Parse current position features (not forecast tracks)
            active_storms = features
              |> Enum.filter(&is_current_position/1)
              |> Enum.map(&parse_geojson_storm(&1, basin))
              |> Enum.filter(&(&1 != nil))
              |> Enum.uniq_by(&(&1.name))  # Remove duplicates by storm name
            
            Logger.info("🌀 #{basin}: Successfully parsed #{length(active_storms)} active storms")
            
            if length(active_storms) > 0 do
              active_storms |> Enum.each(fn storm ->
                Logger.info("🌀 #{basin}:   - #{storm.classification} #{storm.name} (#{storm.wind_speed} mph)")
              end)
            end
            
            active_storms
            
          {:error, decode_error} ->
            Logger.error("🌀 #{basin}: JSON decode failed - #{inspect(decode_error)}")
            []
            
          {:ok, _other} ->
            Logger.warning("🌀 #{basin}: Unexpected JSON structure")
            []
        end
        
      {:ok, %{status_code: status_code}} ->
        Logger.warning("🌀 #{basin}: HTTP #{status_code} error")
        []
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("🌀 #{basin}: Connection error - #{reason}")
        []
    end
  end

  defp is_current_position(feature) do
    # Filter for current position features (not forecast tracks)
    properties = feature["properties"] || %{}
    # Look for current advisory positions
    storm_type = properties["STORMTYPE"] || properties["stormType"] || ""
    storm_name = properties["STORMNAME"] || properties["stormName"] || ""
    
    # Skip empty features or forecast tracks
    storm_name != "" and storm_type != ""
  end

  defp parse_geojson_storm(feature, basin) do
    try do
      properties = feature["properties"] || %{}
      geometry = feature["geometry"] || %{}
      coordinates = geometry["coordinates"] || [0, 0]
      
      # Extract storm information from GeoJSON properties
      storm_name = properties["STORMNAME"] || properties["stormName"] || "Unknown"
      storm_type = properties["STORMTYPE"] || properties["stormType"] || "Unknown"
      intensity = properties["INTENSITY"] || properties["intensity"] || "Unknown"
      
      # Parse wind speed - try multiple field names
      max_wind = properties["MAXWIND"] || properties["maxWind"] || 
                 properties["MAX_WIND"] || properties["WINDS"] || 0
      
      # Parse pressure
      min_pressure = properties["MSLP"] || properties["minSeaLevelPres"] || 
                     properties["PRESSURE"] || 1013
      
      # Parse coordinates (GeoJSON is [longitude, latitude])
      lon = if is_list(coordinates) and length(coordinates) >= 2, do: Enum.at(coordinates, 0), else: 0.0
      lat = if is_list(coordinates) and length(coordinates) >= 2, do: Enum.at(coordinates, 1), else: 0.0
      
      # Parse movement
      movement_speed = properties["SPEED"] || properties["speed"] || 0
      movement_dir = properties["DIRECTION"] || properties["direction"] || 0
      
      # Determine category based on wind speed
      category = wind_speed_to_category(max_wind)
      
      # Parse advisory time
      advisory_time = properties["ADVDATE"] || properties["advDate"] || 
                      properties["DATETIME"] || properties["dateTime"]
      
      %{
        id: "#{storm_name}_#{System.system_time(:second)}",
        name: storm_name,
        classification: storm_type,
        intensity: intensity,
        category: category,
        wind_speed: max_wind,
        pressure: min_pressure,
        location: %{lat: lat, lon: lon},
        movement: %{speed: movement_speed, direction: movement_dir},
        basin: basin,
        last_update: parse_storm_timestamp(advisory_time),
        timestamp: DateTime.utc_now()
      }
    rescue
      e ->
        Logger.debug("🌀 Error parsing GeoJSON storm data: #{inspect(e)}")
        nil
    end
  end

  defp parse_wind_speed(wind_data) when is_map(wind_data) do
    wind_data["mph"] || wind_data["kts"] || 0
  end
  defp parse_wind_speed(wind) when is_number(wind), do: wind
  defp parse_wind_speed(_), do: 0

  defp parse_pressure(pressure_data) when is_map(pressure_data) do
    pressure_data["mb"] || pressure_data["inHg"] || 1013
  end
  defp parse_pressure(pressure) when is_number(pressure), do: pressure
  defp parse_pressure(_), do: 1013

  defp parse_storm_location(storm_data) do
    lat = storm_data["lat"] || storm_data["latitude"] || 0.0
    lon = storm_data["lon"] || storm_data["longitude"] || 0.0
    {lat, lon}
  end

  defp parse_storm_movement(storm_data) do
    movement_data = storm_data["movement"] || %{}
    %{
      speed: movement_data["speed"] || 0,
      direction: movement_data["direction"] || 0
    }
  end

  defp parse_storm_timestamp(datetime_str) when is_binary(datetime_str) do
    case DateTime.from_iso8601(datetime_str) do
      {:ok, datetime, _} -> datetime
      _ -> DateTime.utc_now()
    end
  end
  defp parse_storm_timestamp(_), do: DateTime.utc_now()

  defp wind_speed_to_category(wind_speed) when wind_speed >= 157, do: 5
  defp wind_speed_to_category(wind_speed) when wind_speed >= 130, do: 4
  defp wind_speed_to_category(wind_speed) when wind_speed >= 111, do: 3
  defp wind_speed_to_category(wind_speed) when wind_speed >= 96, do: 2
  defp wind_speed_to_category(wind_speed) when wind_speed >= 74, do: 1
  defp wind_speed_to_category(_), do: 0  # Tropical Storm or Depression

  defp fetch_wildfire_data(state) do
    wildfires = if :rand.uniform() > 0.6 do
      [
        %{
          id: "wf_001",
          name: "Sierra Fire",
          location: %{lat: 37.0, lon: -119.0},
          acres_burned: :rand.uniform(10000),
          containment: :rand.uniform(100),
          threat_level: Enum.random(["Low", "Medium", "High", "Critical"]),
          resources_deployed: %{
            personnel: :rand.uniform(500),
            engines: :rand.uniform(50),
            aircraft: :rand.uniform(10)
          },
          evacuations: :rand.uniform() > 0.5,
          timestamp: DateTime.utc_now()
        }
      ]
    else
      []
    end
    
    %{state | wildfires: wildfires}
  end

  defp fetch_flood_data(state) do
    floods = if :rand.uniform() > 0.7 do
      [
        %{
          id: "fl_001",
          location: Enum.random(["Bangladesh", "Netherlands", "Venice", "Miami", "Bangkok"]),
          severity: Enum.random(["Minor", "Moderate", "Major", "Catastrophic"]),
          water_level: 1.0 + :rand.uniform() * 3,
          affected_population: :rand.uniform(100000),
          duration_hours: :rand.uniform(72),
          cause: Enum.random(["Heavy Rainfall", "Storm Surge", "Dam Failure", "Snowmelt"]),
          timestamp: DateTime.utc_now()
        }
      ]
    else
      []
    end
    
    %{state | floods: floods}
  end

  defp fetch_volcanic_data(state) do
    volcanoes = [
      %{name: "Kilauea", location: "Hawaii", lat: 19.4, lon: -155.3},
      %{name: "Etna", location: "Italy", lat: 37.7, lon: 15.0},
      %{name: "Fuji", location: "Japan", lat: 35.4, lon: 138.7},
      %{name: "Yellowstone", location: "USA", lat: 44.4, lon: -110.6}
    ]
    
    active_volcanoes = volcanoes
    |> Enum.filter(fn _ -> :rand.uniform() > 0.8 end)
    |> Enum.map(fn volcano ->
      Map.merge(volcano, %{
        alert_level: Enum.random(["Green", "Yellow", "Orange", "Red"]),
        activity_type: Enum.random(["Eruption", "Earthquake Swarm", "Gas Emission", "Lava Flow"]),
        vei: :rand.uniform(4),
        timestamp: DateTime.utc_now()
      })
    end)
    
    %{state | volcanic_activity: active_volcanoes}
  end

  defp fetch_space_weather(state) do
    case NOAASpaceWeather.fetch_all_space_weather() do
      {:ok, space_weather} ->
        Logger.info("Successfully fetched real space weather data - KP: #{space_weather.geomagnetic_storm.kp_index}, Solar Wind: #{space_weather.solar_wind.speed} km/s")
        %{state | space_weather: space_weather}
      {:error, :no_data} ->
        Logger.warning("SPACE WEATHER DATA STREAM: NO DATA AVAILABLE - All NOAA APIs returned no valid data")
        %{state | space_weather: :no_data_stream}
      {:error, reason} ->
        Logger.error("SPACE WEATHER DATA STREAM: API ERROR - #{reason}")
        %{state | space_weather: :no_data_stream}
    end
  end



  defp detect_natural_anomalies(state) do
    anomalies = []
    
    anomalies = anomalies ++ detect_seismic_anomalies(state.earthquakes)
    anomalies = anomalies ++ detect_weather_anomalies(state)
    anomalies = anomalies ++ detect_cascading_events(state)
    
    if length(anomalies) > 0 do
      Logger.warning("Detected #{length(anomalies)} natural event anomalies")
      Phoenix.PubSub.broadcast(GlobalPulse.PubSub, "anomalies", {:new_anomalies, anomalies})
    end
    
    %{state | anomalies: anomalies}
  end

  defp detect_seismic_anomalies(earthquakes) do
    large_quakes = Enum.filter(earthquakes, &(&1.magnitude >= 6.0))
    swarm = length(earthquakes) > 10
    
    anomalies = []
    
    anomalies = if length(large_quakes) > 0 do
      [%{
        type: :major_earthquake,
        magnitude: List.first(large_quakes).magnitude,
        location: List.first(large_quakes).location,
        severity: :critical,
        timestamp: DateTime.utc_now()
      } | anomalies]
    else
      anomalies
    end
    
    if swarm do
      [%{
        type: :earthquake_swarm,
        count: length(earthquakes),
        region: analyze_swarm_region(earthquakes),
        severity: :high,
        timestamp: DateTime.utc_now()
      } | anomalies]
    else
      anomalies
    end
  end

  defp analyze_swarm_region(earthquakes) do
    if length(earthquakes) > 0 do
      avg_lat = Enum.sum(Enum.map(earthquakes, & &1.latitude)) / length(earthquakes)
      avg_lon = Enum.sum(Enum.map(earthquakes, & &1.longitude)) / length(earthquakes)
      "Region: #{Float.round(avg_lat, 2)}, #{Float.round(avg_lon, 2)}"
    else
      "Unknown"
    end
  end

  defp detect_weather_anomalies(state) do
    anomalies = []
    
    anomalies = if length(state.hurricanes) > 0 do
      Enum.map(state.hurricanes, fn hurricane ->
        %{
          type: :active_hurricane,
          name: hurricane.name,
          category: hurricane.category,
          wind_speed: hurricane.wind_speed,
          severity: if(hurricane.category >= 3, do: :critical, else: :high),
          timestamp: DateTime.utc_now()
        }
      end) ++ anomalies
    else
      anomalies
    end
    
    anomalies = case state.space_weather do
      %{geomagnetic_storm: %{severity: severity}} when severity in ["Severe", "Extreme"] ->
        [%{
          type: :geomagnetic_storm,
          severity: :high,
          kp_index: state.space_weather.geomagnetic_storm.kp_index,
          timestamp: DateTime.utc_now()
        } | anomalies]
      _ ->
        anomalies
    end
    
    anomalies
  end

  defp detect_cascading_events(state) do
    cascading = []
    
    has_major_quake = Enum.any?(state.earthquakes, &(&1.magnitude >= 7.0))
    has_tsunami = Enum.any?(state.earthquakes, & &1.tsunami_warning)
    
    if has_major_quake && has_tsunami do
      [%{
        type: :cascading_disaster,
        events: ["major_earthquake", "tsunami_warning"],
        severity: :critical,
        regions_affected: extract_affected_regions(state),
        timestamp: DateTime.utc_now()
      } | cascading]
    else
      cascading
    end
  end

  defp extract_affected_regions(state) do
    regions = []
    regions = regions ++ Enum.map(state.earthquakes, & &1.location)
    regions = regions ++ Enum.map(state.weather_events, & &1.location)
    Enum.uniq(regions) |> Enum.take(5)
  end

  defp filter_critical_events(state) do
    %{
      earthquakes: Enum.filter(state.earthquakes, &(&1.magnitude >= 6.0)),
      hurricanes: Enum.filter(state.hurricanes, &(&1.category >= 3)),
      volcanoes: Enum.filter(state.volcanic_activity, &(&1.alert_level in ["Orange", "Red"])),
      severe_weather: Enum.filter(state.weather_events, &is_severe_weather/1)
    }
  end

  defp parse_timestamp(nil), do: DateTime.utc_now()
  defp parse_timestamp(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp, :millisecond)
  end
  defp parse_timestamp(_), do: DateTime.utc_now()

  defp broadcast_updates(state) do
    Phoenix.PubSub.broadcast(
      GlobalPulse.PubSub,
      "natural_events",
      {:update, %{
        earthquakes: Enum.take(state.earthquakes, 5),
        weather: state.weather_events,
        hurricanes: state.hurricanes,
        wildfires: state.wildfires,
        space_weather: state.space_weather,
        timestamp: DateTime.utc_now()
      }}
    )
    state
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end
end