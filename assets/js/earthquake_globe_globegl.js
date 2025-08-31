import Globe from 'globe.gl'

export const EarthquakeGlobe = {
  mounted() {
    console.log('EarthquakeGlobe mounted, starting initialization...')
    console.log('Globe import:', Globe)
    
    try {
      this.initializeGlobe()
      this.updateEarthquakes()
      
      // Hide loading message once initialized
      const loadingDiv = this.el.querySelector('.absolute.inset-0')
      if (loadingDiv) {
        loadingDiv.style.display = 'none'
      }
      console.log('Globe.GL initialization completed successfully')
    } catch (error) {
      console.error('Error initializing Globe.GL:', error)
      
      // Show error message instead of loading
      const loadingDiv = this.el.querySelector('.absolute.inset-0')
      if (loadingDiv) {
        loadingDiv.innerHTML = `
          <div class="text-center text-red-400">
            <div class="mb-2">❌</div>
            <div>Globe.GL failed to load</div>
            <div class="text-xs mt-2">${error.message}</div>
          </div>
        `
      }
    }
  },

  updated() {
    this.updateEarthquakes()
  },

  destroyed() {
    if (this.globe) {
      // Clean up Globe.GL instance
      this.globe._destructor && this.globe._destructor()
    }
  },

  initializeGlobe() {
    console.log('Starting Globe.GL initialization...')
    const container = this.el
    const width = container.offsetWidth
    const height = container.offsetHeight
    
    console.log(`Container dimensions: ${width}x${height}`)
    
    if (!Globe) {
      throw new Error('Globe.GL library not available')
    }
    
    // Create Globe.GL instance with Earth-like configuration
    console.log('Creating Globe instance...')
    this.globe = Globe()
      .width(width)
      .height(height)
      .globeImageUrl('//unpkg.com/three-globe/example/img/earth-blue-marble.jpg') // NASA Earth texture
      .bumpImageUrl('//unpkg.com/three-globe/example/img/earth-topology.png')   // Earth topology
      .showGraticules(false) // Hide grid lines for cleaner look
      .showAtmosphere(true)
      .atmosphereColor('lightskyblue')
      .atmosphereAltitude(0.1)
      .backgroundColor('rgba(0,0,0,0)')
    
    console.log('Globe instance created, mounting to DOM...')
    
    // Mount to container
    this.globe(container)
    
    console.log('Globe mounted, setting up controls...')
    
    // Auto-rotate the globe (if controls are available)
    try {
      const controls = this.globe.controls()
      if (controls) {
        controls.autoRotate = true
        controls.autoRotateSpeed = 0.3
        controls.enableDamping = true
        controls.dampingFactor = 0.02
        controls.minDistance = 200
        controls.maxDistance = 800
      }
    } catch (e) {
      console.log('Controls not available:', e)
    }
    
    // Globe.GL handles lighting automatically
    
    console.log('Globe.GL initialized successfully')
  },

  updateEarthquakes() {
    try {
      // Get earthquake data from the element's dataset
      const earthquakesData = JSON.parse(this.el.dataset.earthquakes || '[]')
      
      console.log(`🌍 GLOBE: Updating globe with ${earthquakesData.length} earthquakes`)
      console.log('🌍 GLOBE: Raw earthquake data:', earthquakesData)
      
      // Use the earthquake data as provided by the backend
      let displayEarthquakes = earthquakesData
      console.log('🌍 GLOBE: Using earthquake data:', displayEarthquakes.length)
      displayEarthquakes.forEach((eq, i) => {
        console.log(`🌍 GLOBE: ${i+1}. M${eq.magnitude} ${eq.location}`)
      })
      
      // Sort earthquakes to match the list order (top 5 get special treatment)
      const sortedEarthquakes = [...displayEarthquakes].sort((a, b) => {
        // Sort by magnitude desc, then by time desc
        if (b.magnitude !== a.magnitude) return b.magnitude - a.magnitude
        return new Date(b.time) - new Date(a.time)
      })
      
      console.log('🌍 GLOBE: Top 5 earthquakes that will get special animation:')
      sortedEarthquakes.slice(0, 5).forEach((eq, i) => {
        console.log(`🌍 GLOBE: ${i+1}. ⭐ M${eq.magnitude} ${eq.location}`)
      })
      
      // Convert earthquake data for Globe.GL
      const globeEarthquakes = displayEarthquakes.map((earthquake, index) => {
        const magnitude = earthquake.magnitude || 4.5
        const isTopFive = sortedEarthquakes.slice(0, 5).includes(earthquake)
        
        return {
          lat: earthquake.latitude,
          lng: earthquake.longitude,
          magnitude: magnitude,
          location: earthquake.location,
          depth: earthquake.depth,
          time: earthquake.time,
          isTopFive: isTopFive,
          // Enhanced color for top 5
          color: isTopFive ? this.getEnhancedMagnitudeColor(magnitude) : this.getMagnitudeColor(magnitude),
          // Larger size for top 5
          size: Math.max(0.2, magnitude * (isTopFive ? 0.3 : 0.2))
        }
      })
      
      // Update points on globe with enhanced visualization
      this.globe
        .pointsData(globeEarthquakes)
        .pointAltitude(0.02)
        .pointColor(d => d.color)
        .pointRadius(d => d.size)
        .pointResolution(20)
        .pointLabel(d => `
          <div style="padding: 10px; background: rgba(0,0,0,0.9); border-radius: 8px; color: white; font-size: 14px; border: 2px solid ${d.color}; box-shadow: 0 4px 12px rgba(0,0,0,0.3);">
            <div style="font-weight: bold; margin-bottom: 5px; color: ${d.color};">${d.location}${d.isTopFive ? ' ⭐' : ''}</div>
            ${d.isTopFive ? '<div style="font-size: 12px; color: #ffab00; margin-bottom: 3px;">📊 Featured in Recent List</div>' : ''}
            <div>🌍 Magnitude: <strong>${d.magnitude}</strong></div>
            <div>📏 Depth: <strong>${d.depth}km</strong></div>
            <div>⏰ Time: <strong>${d.time || 'Unknown'}</strong></div>
          </div>
        `)
        
      // Add rings - top 5 earthquakes get special pulsating rings, major ones get standard rings
      const ringData = []
      
      // Top 5 earthquakes get pulsating rings regardless of magnitude
      globeEarthquakes.filter(eq => eq.isTopFive).forEach(eq => {
        ringData.push({
          lat: eq.lat,
          lng: eq.lng,
          maxR: Math.max(4, eq.magnitude * 2.5),
          propagationSpeed: 1.5,
          repeatPeriod: 1500, // Faster pulsing for top 5
          color: eq.color
        })
      })
      
      // Major earthquakes (6.0+) that aren't in top 5 get standard rings
      globeEarthquakes.filter(eq => eq.magnitude >= 6.0 && !eq.isTopFive).forEach(eq => {
        ringData.push({
          lat: eq.lat,
          lng: eq.lng,
          maxR: eq.magnitude * 3,
          propagationSpeed: 2,
          repeatPeriod: 2500, // Slower pulsing for others
          color: eq.color
        })
      })
      
      this.globe
        .ringsData(ringData)
        .ringColor(d => d.color)
        .ringMaxRadius(d => d.maxR)
        .ringPropagationSpeed(d => d.propagationSpeed)
        .ringRepeatPeriod(d => d.repeatPeriod)
        
    } catch (error) {
      console.error('Error updating earthquake data:', error)
    }
  },
  
  getMagnitudeColor(magnitude) {
    // Beautiful color gradient based on earthquake magnitude
    if (magnitude >= 7.0) {
      return '#ff1744' // Bright red for major earthquakes
    } else if (magnitude >= 6.0) {
      return '#ff5722' // Orange-red for strong
    } else if (magnitude >= 5.0) {
      return '#ff9800' // Orange for moderate
    } else {
      return '#ffc107' // Golden yellow for light
    }
  },
  
  getEnhancedMagnitudeColor(magnitude) {
    // Enhanced, brighter colors for top 5 earthquakes in the list
    if (magnitude >= 7.0) {
      return '#ff0040' // Ultra bright red for major earthquakes
    } else if (magnitude >= 6.0) {
      return '#ff3d00' // Bright orange-red for strong
    } else if (magnitude >= 5.0) {
      return '#ff6f00' // Bright orange for moderate
    } else {
      return '#ffab00' // Bright amber for light
    }
  },
  
  getTestEarthquakes() {
    return [
      { latitude: 35.7, longitude: 139.7, magnitude: 6.2, location: 'Tokyo, Japan', depth: 10, time: '2024-01-15T10:30:00Z' },
      { latitude: 37.7749, longitude: -122.4194, magnitude: 5.8, location: 'San Francisco, USA', depth: 8, time: '2024-01-15T08:15:00Z' },
      { latitude: -33.9249, longitude: 18.4241, magnitude: 4.9, location: 'Cape Town, South Africa', depth: 15, time: '2024-01-15T06:45:00Z' },
      { latitude: 40.7128, longitude: -74.0060, magnitude: 7.1, location: 'New York, USA', depth: 12, time: '2024-01-15T12:20:00Z' },
      { latitude: 51.5074, longitude: -0.1278, magnitude: 5.2, location: 'London, UK', depth: 7, time: '2024-01-15T14:10:00Z' },
      { latitude: -22.9068, longitude: -43.1729, magnitude: 6.5, location: 'Rio de Janeiro, Brazil', depth: 18, time: '2024-01-15T16:30:00Z' },
      { latitude: 55.7558, longitude: 37.6176, magnitude: 4.8, location: 'Moscow, Russia', depth: 5, time: '2024-01-15T18:45:00Z' }
    ]
  }
}