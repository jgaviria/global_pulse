import * as THREE from 'three'

export const ThreeJSMagnetosphere = {
  mounted() {
    this.initThreeJS()
    this.createEarth()
    this.createMagnetosphere()
    this.createRadiationBelts()
    this.createParticleSystem()
    this.startAnimation()
    this.setupResizeObserver()
  },

  updated() {
    const kpIndex = parseFloat(this.el.dataset.kpIndex) || 0
    const solarWindSpeed = parseFloat(this.el.dataset.solarWindSpeed) || 400
    const severity = this.el.dataset.severity || 'Quiet'
    
    this.updateSpaceWeather(kpIndex, solarWindSpeed, severity)
  },

  destroyed() {
    this.cleanup()
  },

  initThreeJS() {
    const container = this.el.querySelector('.threejs-container')
    if (!container) return

    this.width = container.offsetWidth
    this.height = container.offsetHeight

    // Scene setup
    this.scene = new THREE.Scene()
    this.scene.background = new THREE.Color(0x000011)

    // Camera setup
    this.camera = new THREE.PerspectiveCamera(75, this.width / this.height, 0.1, 1000)
    this.camera.position.set(0, 20, 100)
    this.camera.lookAt(0, 0, 0)

    // Renderer setup
    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true })
    this.renderer.setSize(this.width, this.height)
    this.renderer.setPixelRatio(window.devicePixelRatio)
    this.renderer.shadowMap.enabled = true
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap
    container.appendChild(this.renderer.domElement)

    // Lighting
    const ambientLight = new THREE.AmbientLight(0x404040, 0.3)
    this.scene.add(ambientLight)

    const directionalLight = new THREE.DirectionalLight(0xffffff, 1)
    directionalLight.position.set(100, 50, 0)
    directionalLight.castShadow = true
    this.scene.add(directionalLight)

    // Add starfield
    this.createStarfield()
  },

  createStarfield() {
    const starsGeometry = new THREE.BufferGeometry()
    const starsCount = 2000
    const positions = new Float32Array(starsCount * 3)

    for (let i = 0; i < starsCount * 3; i += 3) {
      positions[i] = (Math.random() - 0.5) * 2000
      positions[i + 1] = (Math.random() - 0.5) * 2000
      positions[i + 2] = (Math.random() - 0.5) * 2000
    }

    starsGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3))

    const starsMaterial = new THREE.PointsMaterial({
      color: 0xffffff,
      size: 2,
      transparent: true,
      opacity: 0.8
    })

    const stars = new THREE.Points(starsGeometry, starsMaterial)
    this.scene.add(stars)
  },

  createEarth() {
    // Earth geometry
    const earthGeometry = new THREE.SphereGeometry(6.371, 64, 32)
    
    // Earth materials with realistic textures
    const earthMaterial = new THREE.MeshPhongMaterial({
      color: 0x2563eb,
      shininess: 30,
      transparent: true,
      opacity: 0.9
    })

    this.earth = new THREE.Mesh(earthGeometry, earthMaterial)
    this.earth.castShadow = true
    this.earth.receiveShadow = true
    this.scene.add(this.earth)

    // Earth's atmosphere
    const atmosphereGeometry = new THREE.SphereGeometry(6.6, 64, 32)
    const atmosphereMaterial = new THREE.MeshPhongMaterial({
      color: 0x87ceeb,
      transparent: true,
      opacity: 0.2,
      side: THREE.BackSide
    })

    this.atmosphere = new THREE.Mesh(atmosphereGeometry, atmosphereMaterial)
    this.scene.add(this.atmosphere)

    // Earth rotation
    this.earthRotationSpeed = 0.005
  },

  createMagnetosphere() {
    this.fieldLines = []
    this.fieldLinesGroup = new THREE.Group()
    this.scene.add(this.fieldLinesGroup)

    // Create dipole magnetic field lines
    for (let i = 0; i < 16; i++) {
      const colatitude = Math.PI * (i + 1) / 17
      this.createFieldLine(colatitude)
    }
  },

  createFieldLine(colatitude) {
    const points = []
    const earthRadius = 6.371
    const maxRadius = earthRadius * 6

    // Calculate dipole field line
    for (let r = earthRadius; r <= maxRadius; r += 0.5) {
      const sinColat = Math.sin(colatitude)
      const rho = r * sinColat * sinColat
      
      if (rho <= maxRadius) {
        const z = r * Math.cos(colatitude)
        points.push(new THREE.Vector3(rho, 0, z))
        if (z !== 0) {
          points.unshift(new THREE.Vector3(rho, 0, -z))
        }
      }
    }

    // Create smooth curve
    const curve = new THREE.CatmullRomCurve3(points)
    const tubeGeometry = new THREE.TubeGeometry(curve, 64, 0.1, 8, false)
    
    const fieldLineMaterial = new THREE.MeshBasicMaterial({
      color: 0x3b82f6,
      transparent: true,
      opacity: 0.6
    })

    const fieldLine = new THREE.Mesh(tubeGeometry, fieldLineMaterial)
    this.fieldLinesGroup.add(fieldLine)
    this.fieldLines.push(fieldLine)

    // Rotate to create full 3D field
    for (let angle = 30; angle < 360; angle += 30) {
      const clonedFieldLine = fieldLine.clone()
      clonedFieldLine.rotateY((angle * Math.PI) / 180)
      this.fieldLinesGroup.add(clonedFieldLine)
      this.fieldLines.push(clonedFieldLine)
    }
  },

  createRadiationBelts() {
    // Inner Van Allen Belt
    const innerBeltGeometry = new THREE.TorusGeometry(15, 3, 16, 32)
    const innerBeltMaterial = new THREE.MeshBasicMaterial({
      color: 0xfbbf24,
      transparent: true,
      opacity: 0.3,
      wireframe: false
    })
    this.innerBelt = new THREE.Mesh(innerBeltGeometry, innerBeltMaterial)
    this.innerBelt.rotateX(Math.PI / 2)
    this.scene.add(this.innerBelt)

    // Outer Van Allen Belt  
    const outerBeltGeometry = new THREE.TorusGeometry(25, 5, 16, 32)
    const outerBeltMaterial = new THREE.MeshBasicMaterial({
      color: 0xf59e0b,
      transparent: true,
      opacity: 0.2,
      wireframe: false
    })
    this.outerBelt = new THREE.Mesh(outerBeltGeometry, outerBeltMaterial)
    this.outerBelt.rotateX(Math.PI / 2)
    this.scene.add(this.outerBelt)

    // Belt particles
    this.createBeltParticles()
  },

  createBeltParticles() {
    // Inner belt particles
    const innerParticleCount = 1000
    const innerParticlesGeometry = new THREE.BufferGeometry()
    const innerPositions = new Float32Array(innerParticleCount * 3)
    const innerColors = new Float32Array(innerParticleCount * 3)

    for (let i = 0; i < innerParticleCount * 3; i += 3) {
      const angle = Math.random() * Math.PI * 2
      const radius = 12 + Math.random() * 6
      const height = (Math.random() - 0.5) * 4

      innerPositions[i] = Math.cos(angle) * radius
      innerPositions[i + 1] = height
      innerPositions[i + 2] = Math.sin(angle) * radius

      innerColors[i] = 1      // R
      innerColors[i + 1] = 0.7  // G  
      innerColors[i + 2] = 0.1  // B
    }

    innerParticlesGeometry.setAttribute('position', new THREE.BufferAttribute(innerPositions, 3))
    innerParticlesGeometry.setAttribute('color', new THREE.BufferAttribute(innerColors, 3))

    const innerParticlesMaterial = new THREE.PointsMaterial({
      size: 0.5,
      vertexColors: true,
      transparent: true,
      opacity: 0.8
    })

    this.innerBeltParticles = new THREE.Points(innerParticlesGeometry, innerParticlesMaterial)
    this.scene.add(this.innerBeltParticles)

    // Outer belt particles
    const outerParticleCount = 1500
    const outerParticlesGeometry = new THREE.BufferGeometry()
    const outerPositions = new Float32Array(outerParticleCount * 3)
    const outerColors = new Float32Array(outerParticleCount * 3)

    for (let i = 0; i < outerParticleCount * 3; i += 3) {
      const angle = Math.random() * Math.PI * 2
      const radius = 20 + Math.random() * 10
      const height = (Math.random() - 0.5) * 8

      outerPositions[i] = Math.cos(angle) * radius
      outerPositions[i + 1] = height
      outerPositions[i + 2] = Math.sin(angle) * radius

      outerColors[i] = 1      // R
      outerColors[i + 1] = 0.4  // G
      outerColors[i + 2] = 0.05 // B
    }

    outerParticlesGeometry.setAttribute('position', new THREE.BufferAttribute(outerPositions, 3))
    outerParticlesGeometry.setAttribute('color', new THREE.BufferAttribute(outerColors, 3))

    const outerParticlesMaterial = new THREE.PointsMaterial({
      size: 0.3,
      vertexColors: true,
      transparent: true,
      opacity: 0.6
    })

    this.outerBeltParticles = new THREE.Points(outerParticlesGeometry, outerParticlesMaterial)
    this.scene.add(this.outerBeltParticles)
  },

  createParticleSystem() {
    // Solar wind particles
    const particleCount = 5000
    const particlesGeometry = new THREE.BufferGeometry()
    const positions = new Float32Array(particleCount * 3)
    const velocities = new Float32Array(particleCount * 3)
    const colors = new Float32Array(particleCount * 3)

    for (let i = 0; i < particleCount * 3; i += 3) {
      // Start particles from the left side (Sun direction)
      positions[i] = -150 + Math.random() * 50      // X
      positions[i + 1] = (Math.random() - 0.5) * 100 // Y
      positions[i + 2] = (Math.random() - 0.5) * 100 // Z

      velocities[i] = 0.8 + Math.random() * 0.4     // X velocity
      velocities[i + 1] = (Math.random() - 0.5) * 0.1 // Y velocity
      velocities[i + 2] = (Math.random() - 0.5) * 0.1 // Z velocity

      colors[i] = 1      // R
      colors[i + 1] = 0.8  // G
      colors[i + 2] = 0.2  // B
    }

    particlesGeometry.setAttribute('position', new THREE.BufferAttribute(positions, 3))
    particlesGeometry.setAttribute('velocity', new THREE.BufferAttribute(velocities, 3))
    particlesGeometry.setAttribute('color', new THREE.BufferAttribute(colors, 3))

    const particlesMaterial = new THREE.PointsMaterial({
      size: 0.8,
      vertexColors: true,
      transparent: true,
      opacity: 0.7
    })

    this.solarWindParticles = new THREE.Points(particlesGeometry, particlesMaterial)
    this.scene.add(this.solarWindParticles)
  },

  updateSpaceWeather(kpIndex, solarWindSpeed, severity) {
    // Update field line intensity based on KP index
    const intensity = kpIndex / 9
    this.fieldLines.forEach(fieldLine => {
      fieldLine.material.opacity = 0.3 + intensity * 0.7
      if (intensity > 0.5) {
        fieldLine.material.color.setHex(0xef4444) // Red during storms
      } else {
        fieldLine.material.color.setHex(0x3b82f6) // Blue during quiet
      }
    })

    // Update radiation belt activity
    if (this.innerBelt && this.outerBelt) {
      this.innerBelt.material.opacity = 0.2 + intensity * 0.5
      this.outerBelt.material.opacity = 0.1 + intensity * 0.4
    }

    // Update solar wind speed
    const windFactor = solarWindSpeed / 400
    if (this.solarWindParticles) {
      const velocities = this.solarWindParticles.geometry.attributes.velocity.array
      for (let i = 0; i < velocities.length; i += 3) {
        velocities[i] = (0.8 + Math.random() * 0.4) * windFactor
      }
      this.solarWindParticles.geometry.attributes.velocity.needsUpdate = true
    }

    // Add aurora effects for high KP
    if (kpIndex >= 4) {
      this.createAuroraEffect(kpIndex)
    } else {
      this.removeAuroraEffect()
    }
  },

  createAuroraEffect(kpIndex) {
    if (this.aurora) {
      this.scene.remove(this.aurora)
    }

    const auroraRadius = 7 + kpIndex * 0.5
    const auroraGeometry = new THREE.RingGeometry(auroraRadius, auroraRadius + 2, 32)
    const auroraMaterial = new THREE.MeshBasicMaterial({
      color: kpIndex >= 7 ? 0xef4444 : kpIndex >= 5 ? 0xf59e0b : 0x10b981,
      transparent: true,
      opacity: 0.6,
      side: THREE.DoubleSide
    })

    this.aurora = new THREE.Mesh(auroraGeometry, auroraMaterial)
    this.aurora.rotateX(Math.PI / 2)
    this.scene.add(this.aurora)
  },

  removeAuroraEffect() {
    if (this.aurora) {
      this.scene.remove(this.aurora)
      this.aurora = null
    }
  },

  animate() {
    if (!this.renderer) return

    // Rotate Earth
    if (this.earth) {
      this.earth.rotateY(this.earthRotationSpeed)
    }

    // Rotate radiation belts
    if (this.innerBelt) this.innerBelt.rotateZ(0.01)
    if (this.outerBelt) this.outerBelt.rotateZ(-0.005)

    // Animate belt particles
    if (this.innerBeltParticles) this.innerBeltParticles.rotateY(0.02)
    if (this.outerBeltParticles) this.outerBeltParticles.rotateY(-0.01)

    // Update solar wind particles
    if (this.solarWindParticles) {
      const positions = this.solarWindParticles.geometry.attributes.position.array
      const velocities = this.solarWindParticles.geometry.attributes.velocity.array

      for (let i = 0; i < positions.length; i += 3) {
        positions[i] += velocities[i]
        positions[i + 1] += velocities[i + 1]
        positions[i + 2] += velocities[i + 2]

        // Reset particles that have moved too far
        if (positions[i] > 200) {
          positions[i] = -150 + Math.random() * 50
          positions[i + 1] = (Math.random() - 0.5) * 100
          positions[i + 2] = (Math.random() - 0.5) * 100
        }
      }

      this.solarWindParticles.geometry.attributes.position.needsUpdate = true
    }

    // Gentle camera movement for dynamic view
    const time = Date.now() * 0.0005
    this.camera.position.x = Math.cos(time) * 0.5
    this.camera.position.y = 20 + Math.sin(time * 0.7) * 2
    this.camera.lookAt(0, 0, 0)

    this.renderer.render(this.scene, this.camera)
  },

  startAnimation() {
    const animate = () => {
      this.animationId = requestAnimationFrame(animate)
      this.animate()
    }
    animate()
  },

  setupResizeObserver() {
    this.resizeObserver = new ResizeObserver(entries => {
      this.handleResize()
    })
    this.resizeObserver.observe(this.el)
  },

  handleResize() {
    const container = this.el.querySelector('.threejs-container')
    if (!container) return

    this.width = container.offsetWidth
    this.height = container.offsetHeight

    if (this.camera && this.renderer) {
      this.camera.aspect = this.width / this.height
      this.camera.updateProjectionMatrix()
      this.renderer.setSize(this.width, this.height)
    }
  },

  cleanup() {
    if (this.animationId) {
      cancelAnimationFrame(this.animationId)
    }

    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }

    if (this.renderer) {
      this.renderer.dispose()
    }

    // Clean up Three.js objects
    this.scene?.clear()
  }
}