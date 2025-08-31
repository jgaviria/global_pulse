defmodule GlobalPulse.Services.NOAASpaceWeather do
  @moduledoc """
  Client for NOAA Space Weather Prediction Center APIs
  Fetches real-time space weather data including solar wind, KP index, and solar flares
  """
  
  require Logger
  
  @base_url "https://services.swpc.noaa.gov"
  @timeout 10_000
  
  @doc """
  Fetches all space weather data from NOAA SWPC
  """
  def fetch_all_space_weather do
    Logger.info("🚀 NOAA Space Weather: Starting complete data refresh...")
    
    with {:ok, solar_wind} <- fetch_solar_wind(),
         {:ok, kp_index} <- fetch_kp_index(),
         {:ok, solar_flares} <- fetch_solar_flares(),
         {:ok, geomagnetic} <- fetch_geomagnetic_data() do
      
      complete_data = %{
        solar_wind: solar_wind,
        geomagnetic_storm: geomagnetic,
        solar_flares: solar_flares,
        radiation_storm: check_radiation_storm(solar_flares),
        timestamp: DateTime.utc_now()
      }
      
      Logger.info("✅ NOAA Space Weather: Successfully fetched all data")
      Logger.info("📋 SUMMARY:")
      Logger.info("   🌞 Solar Wind: #{complete_data.solar_wind.speed} km/s")
      Logger.info("   🧲 Geomagnetic: KP #{complete_data.geomagnetic_storm.kp_index} (#{complete_data.geomagnetic_storm.severity})")
      Logger.info("   💥 Solar Flares: #{length(complete_data.solar_flares)} active")
      Logger.info("   ☢️  Radiation Storm: #{if complete_data.radiation_storm, do: "ACTIVE", else: "None"}")
      
      {:ok, complete_data}
    else
      {:error, reason} ->
        Logger.error("❌ NOAA Space Weather: Failed to fetch complete data: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Fetches real-time solar wind data (speed, density, temperature)
  """
  def fetch_solar_wind do
    url = "#{@base_url}/products/solar-wind/plasma-5-minute.json"
    Logger.info("🌞 NOAA Solar Wind API: Fetching from #{url}")
    
    case HTTPoison.get(url, [], timeout: @timeout, recv_timeout: @timeout) do
      {:ok, %{status_code: 200, body: body}} ->
        Logger.info("🌞 NOAA Solar Wind API: Raw Response (#{byte_size(body)} bytes)")
        Logger.info("📊 Raw Solar Wind Data: #{String.slice(body, 0, 500)}#{if byte_size(body) > 500, do: "...", else: ""}")
        parse_solar_wind(body)
      {:ok, %{status_code: status_code}} ->
        Logger.warning("🌞 NOAA Solar Wind API: HTTP #{status_code} error")
        {:error, "Solar wind API returned status #{status_code}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("🌞 NOAA Solar Wind API: Connection error - #{reason}")
        {:error, "Solar wind API error: #{reason}"}
    end
  end
  
  @doc """
  Fetches current KP index and geomagnetic storm data
  """
  def fetch_kp_index do
    url = "#{@base_url}/products/noaa-planetary-k-index.json"
    Logger.info("🧲 NOAA KP Index API: Fetching from #{url}")
    
    case HTTPoison.get(url, [], timeout: @timeout, recv_timeout: @timeout) do
      {:ok, %{status_code: 200, body: body}} ->
        Logger.info("🧲 NOAA KP Index API: Raw Response (#{byte_size(body)} bytes)")
        Logger.info("📊 Raw KP Index Data: #{String.slice(body, 0, 500)}#{if byte_size(body) > 500, do: "...", else: ""}")
        parse_kp_index(body)
      {:ok, %{status_code: status_code}} ->
        Logger.warning("🧲 NOAA KP Index API: HTTP #{status_code} error")
        {:error, "KP index API returned status #{status_code}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("🧲 NOAA KP Index API: Connection error - #{reason}")
        {:error, "KP index API error: #{reason}"}
    end
  end
  
  @doc """
  Fetches recent solar flare data
  """
  def fetch_solar_flares do
    url = "#{@base_url}/json/goes/primary/xrays-6-hour.json"
    Logger.info("💥 NOAA Solar Flares API: Fetching from #{url}")
    
    case HTTPoison.get(url, [], timeout: @timeout, recv_timeout: @timeout) do
      {:ok, %{status_code: 200, body: body}} ->
        Logger.info("💥 NOAA Solar Flares API: Raw Response (#{byte_size(body)} bytes)")
        Logger.info("📊 Raw Solar Flares Data: #{String.slice(body, 0, 500)}#{if byte_size(body) > 500, do: "...", else: ""}")
        parse_solar_flares(body)
      {:ok, %{status_code: status_code}} ->
        Logger.warning("💥 NOAA Solar Flares API: HTTP #{status_code} error")
        {:error, "Solar flares API returned status #{status_code}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("💥 NOAA Solar Flares API: Connection error - #{reason}")
        {:error, "Solar flares API error: #{reason}"}
    end
  end
  
  @doc """
  Fetches geomagnetic storm forecast and current conditions
  """
  def fetch_geomagnetic_data do
    url = "#{@base_url}/products/noaa-scales.json"
    Logger.info("🌍 NOAA Geomagnetic API: Fetching from #{url}")
    
    case HTTPoison.get(url, [], timeout: @timeout, recv_timeout: @timeout) do
      {:ok, %{status_code: 200, body: body}} ->
        Logger.info("🌍 NOAA Geomagnetic API: Raw Response (#{byte_size(body)} bytes)")
        Logger.info("📊 Raw Geomagnetic Data: #{String.slice(body, 0, 500)}#{if byte_size(body) > 500, do: "...", else: ""}")
        parse_geomagnetic_data(body)
      {:ok, %{status_code: status_code}} ->
        Logger.warning("🌍 NOAA Geomagnetic API: HTTP #{status_code} error")
        {:error, :no_data}
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("🌍 NOAA Geomagnetic API: Connection error - #{reason}")
        {:error, :no_data}
    end
  end
  
  # Parser functions
  
  defp parse_solar_wind(body) do
    case Jason.decode(body) do
      {:ok, data} ->
        # Skip header row and get the most recent non-null data point
        recent_data = data
          |> Enum.drop(1)  # Skip header row
          |> Enum.reverse()
          |> Enum.find(fn [_time, density, speed, temperature | _] -> 
            density != nil and speed != nil and temperature != nil
          end)
        
        case recent_data do
          [_time, density_str, speed_str, temperature_str | _] when is_binary(density_str) ->
            # Parse strings to numbers (handle both integers and floats)
            density = parse_number(density_str)
            speed = parse_number(speed_str)
            temperature = parse_number(temperature_str)
            
            parsed_data = %{
              speed: round(speed),  # km/s
              density: Float.round(density, 2),  # particles/cm³
              temperature: round(temperature)  # Kelvin
            }
            Logger.info("🌞 Parsed Solar Wind: Speed=#{parsed_data.speed} km/s, Density=#{parsed_data.density} p/cm³, Temp=#{parsed_data.temperature} K")
            {:ok, parsed_data}
          _ ->
            Logger.warning("NOAA Space Weather: No valid solar wind data available from API")
            {:error, :no_data}
        end
      {:error, _} ->
        {:error, "Failed to parse solar wind data"}
    end
  end
  
  defp parse_kp_index(body) do
    case Jason.decode(body) do
      {:ok, data} ->
        # Skip header row and get the most recent KP value  
        recent_kp = data
          |> Enum.drop(1)  # Skip header row
          |> Enum.reverse()
          |> Enum.find(fn item -> 
            is_list(item) && length(item) >= 2 && Enum.at(item, 1) != nil
          end)
        
        case recent_kp do
          [_time, kp_str | _] when is_binary(kp_str) ->
            kp = parse_number(kp_str)
            parsed_kp = Float.round(kp, 1)
            Logger.info("🧲 Parsed KP Index: #{parsed_kp} (#{calculate_severity(parsed_kp)} geomagnetic activity)")
            {:ok, parsed_kp}
          _ ->
            Logger.warning("NOAA Space Weather: No valid KP index data available from API")
            {:error, :no_data}
        end
      {:error, _} ->
        {:error, "Failed to parse KP index data"}
    end
  end
  
  defp parse_solar_flares(body) do
    case Jason.decode(body) do
      {:ok, data} ->
        # Detect flares from X-ray flux data
        flares = detect_flares_from_xray(data)
        Logger.info("💥 Parsed Solar Flares: Found #{length(flares)} recent flares")
        if length(flares) > 0 do
          flares |> Enum.each(fn flare ->
            Logger.info("💥   - #{flare.class}#{flare.magnitude} flare at #{flare.peak_time} (flux: #{flare.flux})")
          end)
        end
        {:ok, flares}
      {:error, _} ->
        {:error, "Failed to parse solar flare data"}
    end
  end
  
  defp detect_flares_from_xray(data) do
    # X-ray flux thresholds for flare classification
    # C-class: 1e-6 W/m²
    # M-class: 1e-5 W/m²
    # X-class: 1e-4 W/m²
    
    data
    |> Enum.reverse()
    |> Enum.take(100)  # Look at recent data points
    |> Enum.filter(fn item ->
      case item do
        %{"flux" => flux} when is_number(flux) ->
          flux >= 1.0e-6  # C-class or higher
        _ -> false
      end
    end)
    |> Enum.map(fn item ->
      flux = item["flux"]
      time = item["time_tag"]
      
      {class, magnitude} = classify_flare(flux)
      
      %{
        class: class,
        magnitude: magnitude,
        peak_time: parse_time(time),
        flux: flux
      }
    end)
    |> Enum.take(5)  # Return up to 5 recent flares
  end
  
  defp classify_flare(flux) when is_number(flux) do
    cond do
      flux >= 1.0e-4 ->
        {"X", Float.round(flux / 1.0e-4, 1)}
      flux >= 1.0e-5 ->
        {"M", Float.round(flux / 1.0e-5, 1)}
      flux >= 1.0e-6 ->
        {"C", Float.round(flux / 1.0e-6, 1)}
      true ->
        {"B", Float.round(flux / 1.0e-7, 1)}
    end
  end
  
  defp parse_time(time_string) when is_binary(time_string) do
    case DateTime.from_iso8601(time_string) do
      {:ok, datetime, _} -> datetime
      _ -> DateTime.utc_now()
    end
  end
  defp parse_time(_), do: DateTime.utc_now()
  
  defp parse_geomagnetic_data(body) do
    case Jason.decode(body) do
      {:ok, %{"-1" => scales}} ->
        # Get G-scale (geomagnetic) data
        g_scale = Map.get(scales, "G", %{"Scale" => "0"})
        scale_value = String.to_integer(Map.get(g_scale, "Scale", "0"))
        
        geomagnetic_data = build_geomagnetic_data(scale_value)
        Logger.info("🌍 Parsed Geomagnetic: G#{geomagnetic_data.g_scale} scale, KP=#{geomagnetic_data.kp_index}, Severity=#{geomagnetic_data.severity}")
        Logger.info("🌍   Aurora visible at latitude: #{geomagnetic_data.aurora_visibility_lat}°")
        {:ok, geomagnetic_data}
      {:ok, _} ->
        Logger.warning("NOAA Space Weather: Unexpected geomagnetic data structure from API")
        {:error, :no_data}
      {:error, _} ->
        {:error, "Failed to parse geomagnetic data"}
    end
  end
  
  defp build_geomagnetic_data(g_scale) do
    # G-scale to KP index approximation
    kp_index = case g_scale do
      5 -> 9.0  # G5 Extreme
      4 -> 8.0  # G4 Severe
      3 -> 7.0  # G3 Strong
      2 -> 6.0  # G2 Moderate
      1 -> 5.0  # G1 Minor
      _ -> 3.0  # G0 None/Quiet
    end
    
    %{
      kp_index: kp_index,
      severity: calculate_severity(kp_index),
      aurora_visibility_lat: calculate_aurora_latitude(kp_index),
      g_scale: calculate_g_scale(kp_index)
    }
  end
  
  defp calculate_severity(kp) do
    cond do
      kp >= 9 -> "Extreme"
      kp >= 8 -> "Severe"
      kp >= 7 -> "Strong"
      kp >= 6 -> "Moderate"
      kp >= 5 -> "Minor"
      true -> "None"
    end
  end
  
  defp calculate_aurora_latitude(kp) do
    # Approximate aurora visibility latitude based on KP index
    # Higher KP = aurora visible at lower latitudes
    case kp do
      k when k >= 9 -> 45  # Visible as far south as Portland/Minneapolis
      k when k >= 8 -> 50  # Visible in southern Canada
      k when k >= 7 -> 52
      k when k >= 6 -> 55
      k when k >= 5 -> 58
      k when k >= 4 -> 62
      k when k >= 3 -> 65
      _ -> 67  # Only visible in far north
    end
  end
  
  defp calculate_g_scale(kp) do
    cond do
      kp >= 9 -> 5  # G5
      kp >= 8 -> 4  # G4
      kp >= 7 -> 3  # G3
      kp >= 6 -> 2  # G2
      kp >= 5 -> 1  # G1
      true -> 0     # G0
    end
  end
  
  defp check_radiation_storm(flares) do
    # Check if any recent X-class flares (potential radiation storm)
    Enum.any?(flares, fn flare ->
      flare.class == "X" && flare.magnitude >= 2.0
    end)
  end
  
  # Helper function to parse string numbers (handles both integers and floats)
  defp parse_number(str) when is_binary(str) do
    cond do
      String.contains?(str, ".") ->
        String.to_float(str)
      true ->
        String.to_integer(str) * 1.0
    end
  end
end