import * as THREE from 'three'

export const EarthquakeGlobe = {
  mounted() {
    this.initializeGlobe()
    this.updateEarthquakes()
    
    // Hide loading message once initialized
    const loadingDiv = this.el.querySelector('.absolute.inset-0')
    if (loadingDiv) {
      loadingDiv.style.display = 'none'
    }
    
    // Auto-rotate and update
    this.animate()
  },

  updated() {
    this.updateEarthquakes()
  },

  destroyed() {
    if (this.animationId) {
      cancelAnimationFrame(this.animationId)
    }
    if (this.renderer) {
      this.renderer.dispose()
    }
  },

  initializeGlobe() {
    const container = this.el
    const width = container.offsetWidth
    const height = container.offsetHeight
    
    // Scene setup
    this.scene = new THREE.Scene()
    this.scene.background = new THREE.Color(0x000811) // Deep space blue
    
    // Camera setup
    this.camera = new THREE.PerspectiveCamera(75, width / height, 0.1, 1000)
    this.camera.position.set(0, 0, 3)
    
    // Renderer setup
    this.renderer = new THREE.WebGLRenderer({ 
      antialias: true, 
      alpha: true,
      powerPreference: "high-performance"
    })
    this.renderer.setSize(width, height)
    this.renderer.shadowMap.enabled = true
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap
    container.appendChild(this.renderer.domElement)
    
    // Create Earth
    this.createEarth()
    
    // Create atmosphere glow
    this.createAtmosphere()
    
    // Lighting
    this.setupLighting()
    
    // Initialize earthquake markers group
    this.earthquakeGroup = new THREE.Group()
    this.scene.add(this.earthquakeGroup)
    
    // Mouse controls for rotation
    this.setupControls()
  },

  createEarth() {
    // Earth geometry with higher detail
    const earthGeometry = new THREE.SphereGeometry(1, 64, 64)
    
    // Create realistic Earth material with procedural textures
    const earthMaterial = new THREE.MeshPhongMaterial({
      color: 0x6b93d6, // Ocean blue base
      emissive: 0x1a237e, // Subtle blue glow
      shininess: 20,
      transparent: false,
      opacity: 1.0
    })
    
    // Add land mass texture using a simple noise pattern
    this.addLandMasses(earthMaterial)
    
    this.earth = new THREE.Mesh(earthGeometry, earthMaterial)
    this.earth.receiveShadow = true
    this.earth.castShadow = true
    this.scene.add(this.earth)
    
    // Add continent overlays
    this.createContinentOverlays()
    
    // Create subtle latitude/longitude grid
    this.createSubtleGrid()
  },
  
  addLandMasses(earthMaterial) {
    // Create procedural land texture using canvas
    const canvas = document.createElement('canvas')
    canvas.width = 512
    canvas.height = 256
    const ctx = canvas.getContext('2d')
    
    // Create ocean base
    ctx.fillStyle = '#4a90e2'
    ctx.fillRect(0, 0, canvas.width, canvas.height)
    
    // Add simplified continent shapes
    ctx.fillStyle = '#8fbc8f'
    
    // North America
    ctx.beginPath()
    ctx.moveTo(50, 80)
    ctx.lineTo(120, 70)
    ctx.lineTo(130, 100)
    ctx.lineTo(100, 120)
    ctx.lineTo(60, 110)
    ctx.closePath()
    ctx.fill()
    
    // South America
    ctx.beginPath()
    ctx.moveTo(110, 130)
    ctx.lineTo(130, 140)
    ctx.lineTo(125, 180)
    ctx.lineTo(105, 200)
    ctx.lineTo(95, 170)
    ctx.closePath()
    ctx.fill()
    
    // Europe/Africa
    ctx.beginPath()
    ctx.moveTo(200, 80)
    ctx.lineTo(230, 75)
    ctx.lineTo(240, 100)
    ctx.lineTo(250, 140)
    ctx.lineTo(230, 180)
    ctx.lineTo(200, 160)
    ctx.lineTo(190, 120)
    ctx.closePath()
    ctx.fill()
    
    // Asia
    ctx.beginPath()
    ctx.moveTo(260, 70)
    ctx.lineTo(350, 65)
    ctx.lineTo(380, 90)
    ctx.lineTo(370, 120)
    ctx.lineTo(320, 110)
    ctx.lineTo(280, 100)
    ctx.closePath()
    ctx.fill()
    
    // Australia
    ctx.beginPath()
    ctx.moveTo(330, 160)
    ctx.lineTo(370, 155)
    ctx.lineTo(375, 175)
    ctx.lineTo(340, 180)
    ctx.closePath()
    ctx.fill()
    
    // Create texture from canvas
    const texture = new THREE.CanvasTexture(canvas)
    texture.wrapS = THREE.RepeatWrapping
    texture.wrapT = THREE.ClampToEdgeWrapping
    
    earthMaterial.map = texture
    earthMaterial.needsUpdate = true
  },
  
  createSubtleGrid() {
    // Create very subtle grid lines
    const gridMaterial = new THREE.LineBasicMaterial({
      color: 0x4a90e2,
      transparent: true,
      opacity: 0.1
    })
    
    // Major latitude lines only
    for (let lat = -60; lat <= 60; lat += 30) {
      const latRad = (lat * Math.PI) / 180
      const radius = Math.cos(latRad)
      const y = Math.sin(latRad)
      
      const points = []
      for (let lng = 0; lng <= 360; lng += 10) {
        const lngRad = (lng * Math.PI) / 180
        const x = radius * Math.cos(lngRad)
        const z = radius * Math.sin(lngRad)
        points.push(new THREE.Vector3(x, y, z))
      }
      
      const geometry = new THREE.BufferGeometry().setFromPoints(points)
      const line = new THREE.Line(geometry, gridMaterial)
      this.earth.add(line)
    }
    
    // Major longitude lines only
    for (let lng = 0; lng < 360; lng += 30) {
      const lngRad = (lng * Math.PI) / 180
      
      const points = []
      for (let lat = -90; lat <= 90; lat += 5) {
        const latRad = (lat * Math.PI) / 180
        const x = Math.cos(latRad) * Math.cos(lngRad)
        const y = Math.sin(latRad)
        const z = Math.cos(latRad) * Math.sin(lngRad)
        points.push(new THREE.Vector3(x, y, z))
      }
      
      const geometry = new THREE.BufferGeometry().setFromPoints(points)
      const line = new THREE.Line(geometry, gridMaterial)
      this.earth.add(line)
    }
    
    // Subtle equator highlight
    const equatorPoints = []
    for (let lng = 0; lng <= 360; lng += 3) {
      const lngRad = (lng * Math.PI) / 180
      const x = Math.cos(lngRad)
      const z = Math.sin(lngRad)
      equatorPoints.push(new THREE.Vector3(x, 0, z))
    }
    
    const equatorGeometry = new THREE.BufferGeometry().setFromPoints(equatorPoints)
    const equatorMaterial = new THREE.LineBasicMaterial({
      color: 0x00ff88,
      transparent: true,
      opacity: 0.3
    })
    
    const equatorLine = new THREE.Line(equatorGeometry, equatorMaterial)
    this.earth.add(equatorLine)
  },
  
  createContinentOverlays() {
    // Add subtle city markers to show populated areas
    const majorCities = [
      // Major population centers
      { name: 'New York', lat: 40.7, lng: -74.0 },
      { name: 'Los Angeles', lat: 34.0, lng: -118.2 },
      { name: 'London', lat: 51.5, lng: -0.1 },
      { name: 'Tokyo', lat: 35.7, lng: 139.7 },
      { name: 'Beijing', lat: 39.9, lng: 116.4 },
      { name: 'Mumbai', lat: 19.1, lng: 72.9 },
      { name: 'Sydney', lat: -33.9, lng: 151.2 },
      { name: 'Sao Paulo', lat: -23.5, lng: -46.6 },
      { name: 'Cairo', lat: 30.0, lng: 31.2 },
      { name: 'Lagos', lat: 6.5, lng: 3.4 }
    ]
    
    majorCities.forEach((city) => {
      const lat = city.lat * Math.PI / 180
      const lng = city.lng * Math.PI / 180
      const radius = 1.005
      
      const x = radius * Math.cos(lat) * Math.cos(lng)
      const y = radius * Math.sin(lat)
      const z = radius * Math.cos(lat) * Math.sin(lng)
      
      // Small city marker
      const cityGeometry = new THREE.SphereGeometry(0.003, 8, 8)
      const cityMaterial = new THREE.MeshBasicMaterial({
        color: 0xffa500,
        emissive: 0x663300,
        transparent: true,
        opacity: 0.8
      })
      
      const cityDot = new THREE.Mesh(cityGeometry, cityMaterial)
      cityDot.position.set(x, y, z)
      this.earth.add(cityDot)
    })
  },

  createAtmosphere() {
    // Beautiful atmosphere glow effect
    const atmosphereGeometry = new THREE.SphereGeometry(1.08, 64, 64)
    const atmosphereMaterial = new THREE.MeshBasicMaterial({
      color: 0x87ceeb,
      transparent: true,
      opacity: 0.12,
      side: THREE.BackSide,
      blending: THREE.AdditiveBlending
    })
    
    this.atmosphere = new THREE.Mesh(atmosphereGeometry, atmosphereMaterial)
    this.scene.add(this.atmosphere)
    
    // Add inner glow
    const innerGlowGeometry = new THREE.SphereGeometry(1.02, 32, 32)
    const innerGlowMaterial = new THREE.MeshBasicMaterial({
      color: 0x60a5fa,
      transparent: true,
      opacity: 0.08,
      side: THREE.BackSide,
      blending: THREE.AdditiveBlending
    })
    
    this.innerGlow = new THREE.Mesh(innerGlowGeometry, innerGlowMaterial)
    this.scene.add(this.innerGlow)
  },

  setupLighting() {
    // Soft ambient light
    const ambientLight = new THREE.AmbientLight(0x87ceeb, 0.3)
    this.scene.add(ambientLight)
    
    // Main directional light (sun)
    const sunLight = new THREE.DirectionalLight(0xffffff, 0.8)
    sunLight.position.set(3, 2, 4)
    sunLight.castShadow = true
    sunLight.shadow.mapSize.width = 2048
    sunLight.shadow.mapSize.height = 2048
    sunLight.shadow.camera.near = 0.1
    sunLight.shadow.camera.far = 50
    this.scene.add(sunLight)
    
    // Rim lighting for edge definition
    const rimLight = new THREE.DirectionalLight(0x60a5fa, 0.3)
    rimLight.position.set(-2, 1, -3)
    this.scene.add(rimLight)
    
    // Subtle point light for atmosphere
    const atmosphereLight = new THREE.PointLight(0x3b82f6, 0.2, 8)
    atmosphereLight.position.set(0, 0, 3)
    this.scene.add(atmosphereLight)
  },

  setupControls() {
    this.isMouseDown = false
    this.previousMousePosition = { x: 0, y: 0 }
    
    this.el.addEventListener('mousedown', (e) => {
      this.isMouseDown = true
      this.previousMousePosition = { x: e.clientX, y: e.clientY }
    })
    
    this.el.addEventListener('mouseup', () => {
      this.isMouseDown = false
    })
    
    this.el.addEventListener('mouseleave', () => {
      this.isMouseDown = false
    })
    
    this.el.addEventListener('mousemove', (e) => {
      if (!this.isMouseDown) return
      
      const deltaMove = {
        x: e.clientX - this.previousMousePosition.x,
        y: e.clientY - this.previousMousePosition.y
      }
      
      const deltaRotationQuaternion = new THREE.Quaternion()
        .setFromEuler(new THREE.Euler(
          deltaMove.y * 0.01,
          deltaMove.x * 0.01,
          0,
          'XYZ'
        ))
      
      this.earth.quaternion.multiplyQuaternions(deltaRotationQuaternion, this.earth.quaternion)
      this.earthquakeGroup.quaternion.multiplyQuaternions(deltaRotationQuaternion, this.earthquakeGroup.quaternion)
      
      this.previousMousePosition = { x: e.clientX, y: e.clientY }
    })
  },

  updateEarthquakes() {
    try {
      // Clear existing earthquake markers
      while (this.earthquakeGroup.children.length > 0) {
        this.earthquakeGroup.remove(this.earthquakeGroup.children[0])
      }
      
      // Get earthquake data from the element's dataset
      const earthquakesData = JSON.parse(this.el.dataset.earthquakes || '[]')
      
      console.log('Earthquake data received:', earthquakesData.length, 'earthquakes')
      
      if (earthquakesData.length === 0) {
        console.log('No earthquake data available, creating test markers')
        this.createTestEarthquakes()
      } else {
        earthquakesData.forEach((earthquake, index) => {
          this.createEarthquakeMarker(earthquake, index)
        })
      }
      
    } catch (error) {
      console.error('Error updating earthquake markers:', error)
      this.createTestEarthquakes()
    }
  },
  
  createTestEarthquakes() {
    // Create some test earthquake markers for demonstration
    const testEarthquakes = [
      { latitude: 35.7, longitude: 139.7, magnitude: 6.2, location: 'Tokyo, Japan', depth: 10 },
      { latitude: 37.7749, longitude: -122.4194, magnitude: 5.8, location: 'San Francisco, USA', depth: 8 },
      { latitude: -33.9249, longitude: 18.4241, magnitude: 4.9, location: 'Cape Town, South Africa', depth: 15 },
      { latitude: 40.7128, longitude: -74.0060, magnitude: 7.1, location: 'New York, USA', depth: 12 },
      { latitude: 51.5074, longitude: -0.1278, magnitude: 5.2, location: 'London, UK', depth: 7 }
    ]
    
    testEarthquakes.forEach((earthquake, index) => {
      this.createEarthquakeMarker(earthquake, index)
    })
    
    console.log('Created test earthquake markers:', testEarthquakes.length)
  },

  createEarthquakeMarker(earthquake, index) {
    // Convert lat/lng to 3D coordinates on sphere
    const lat = earthquake.latitude * Math.PI / 180
    const lng = earthquake.longitude * Math.PI / 180
    const radius = 1.03 // Slightly above Earth surface
    
    const x = radius * Math.cos(lat) * Math.cos(lng)
    const y = radius * Math.sin(lat)
    const z = radius * Math.cos(lat) * Math.sin(lng)
    
    // Create marker based on magnitude
    const magnitude = earthquake.magnitude || 4.5
    const markerSize = Math.max(0.015, magnitude * 0.012) // Scale with magnitude
    
    // Beautiful color based on magnitude with glow
    let markerColor, glowColor
    if (magnitude >= 7.0) {
      markerColor = 0xff1744 // Bright red for major earthquakes
      glowColor = 0xff5722
    } else if (magnitude >= 6.0) {
      markerColor = 0xff5722 // Orange-red for strong
      glowColor = 0xff9800
    } else if (magnitude >= 5.0) {
      markerColor = 0xff9800 // Orange for moderate
      glowColor = 0xffc107
    } else {
      markerColor = 0xffc107 // Golden yellow for light
      glowColor = 0xffeb3b
    }
    
    // Create beautiful glowing marker
    const markerGeometry = new THREE.SphereGeometry(markerSize, 16, 16)
    const markerMaterial = new THREE.MeshBasicMaterial({
      color: markerColor,
      transparent: true,
      opacity: 0.9,
      emissive: markerColor,
      emissiveIntensity: 0.3
    })
    
    const marker = new THREE.Mesh(markerGeometry, markerMaterial)
    marker.position.set(x, y, z)
    
    // Create multiple ring effects for beautiful pulsing
    const rings = []
    for (let i = 0; i < 3; i++) {
      const ringSize = markerSize * (2 + i * 0.5)
      const ringGeometry = new THREE.RingGeometry(ringSize, ringSize + 0.002, 32)
      const ringMaterial = new THREE.MeshBasicMaterial({
        color: glowColor,
        transparent: true,
        opacity: 0.4 - i * 0.1,
        side: THREE.DoubleSide,
        blending: THREE.AdditiveBlending
      })
      
      const ring = new THREE.Mesh(ringGeometry, ringMaterial)
      ring.position.copy(marker.position)
      ring.lookAt(new THREE.Vector3(0, 0, 0))
      rings.push(ring)
      this.earthquakeGroup.add(ring)
    }
    
    // Store earthquake data for animation
    marker.userData = {
      earthquake: earthquake,
      originalSize: markerSize,
      phase: index * 0.5,
      rings: rings,
      magnitude: magnitude
    }
    
    this.earthquakeGroup.add(marker)
  },

  animate() {
    this.animationId = requestAnimationFrame(() => this.animate())
    
    const time = Date.now() * 0.001
    
    // Auto-rotate Earth slowly
    if (!this.isMouseDown) {
      this.earth.rotation.y += 0.002
      this.earthquakeGroup.rotation.y += 0.002
    }
    
    // Animate earthquake markers - beautiful pulsing effect
    this.earthquakeGroup.children.forEach((child) => {
      if (child.userData && child.userData.earthquake) {
        const marker = child
        const userData = marker.userData
        
        // Smooth pulsing animation for marker
        const pulseScale = 1 + Math.sin(time * 2 + userData.phase) * 0.2
        marker.scale.setScalar(pulseScale)
        
        // Animate multiple rings with different speeds
        if (userData.rings) {
          userData.rings.forEach((ring, ringIndex) => {
            const ringSpeed = 1.5 + ringIndex * 0.3
            const ringPulse = 1 + Math.sin(time * ringSpeed + userData.phase + ringIndex) * 0.4
            ring.scale.setScalar(ringPulse)
            
            // Fade rings in and out
            const fadePhase = time * 0.8 + userData.phase + ringIndex * 0.7
            const opacity = (0.3 - ringIndex * 0.08) * (0.5 + 0.5 * Math.sin(fadePhase))
            ring.material.opacity = Math.max(0.05, opacity)
          })
        }
        
        // Dynamic glow intensity based on magnitude
        const magnitude = userData.magnitude || 4.5
        const baseIntensity = 0.7 + (magnitude - 4.5) * 0.1
        const glowPulse = Math.sin(time * 1.2 + userData.phase) * 0.15
        marker.material.opacity = Math.max(0.5, Math.min(1.0, baseIntensity + glowPulse))
        
        // Emissive intensity animation
        const emissiveIntensity = 0.2 + Math.sin(time * 1.5 + userData.phase) * 0.1
        marker.material.emissiveIntensity = emissiveIntensity
      }
    })
    
    this.renderer.render(this.scene, this.camera)
  }
}