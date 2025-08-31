import * as d3 from 'd3'
import { gsap } from 'gsap'

export const MagnetosphereAnimation = {
  mounted() {
    console.log('MagnetosphereAnimation mounted')
    this.initializeVanAllenVisualization()
    this.setupResizeObserver()
    this.startRadiationBeltAnimation()
  },

  updated() {
    // Update Van Allen belts based on new space weather data
    const kpIndex = parseFloat(this.el.dataset.kpIndex) || 3
    const solarWindSpeed = parseFloat(this.el.dataset.solarWindSpeed) || 400
    const severity = this.el.dataset.severity || 'Minor'
    
    console.log('Updating with KP:', kpIndex, 'Severity:', severity)
    this.updateRadiationBelts(kpIndex, solarWindSpeed, severity)
  },

  destroyed() {
    this.cleanup()
  },

  initializeAnimation() {
    const container = this.el.querySelector('.magnetosphere-container')
    if (!container) return

    // Set up dimensions
    this.width = container.offsetWidth
    this.height = container.offsetHeight
    this.centerX = this.width / 2
    this.centerY = this.height / 2

    // Create SVG container
    this.svg = d3.select(container)
      .append('svg')
      .attr('width', this.width)
      .attr('height', this.height)
      .style('position', 'absolute')
      .style('top', 0)
      .style('left', 0)
      .style('z-index', 10)

    // Create canvas for particle effects
    this.canvas = d3.select(container)
      .append('canvas')
      .attr('width', this.width)
      .attr('height', this.height)
      .style('position', 'absolute')
      .style('top', 0)
      .style('left', 0)
      .style('z-index', 5)

    this.ctx = this.canvas.node().getContext('2d')

    // Initialize animation state
    this.particles = []
    this.fieldLines = []
    this.animationId = null
    this.lastTime = 0

    this.setupGradients()
    this.createFieldLines()
    this.createParticleSystem()
    this.createRadiationBelts()
  },

  setupGradients() {
    const defs = this.svg.append('defs')

    // Aurora gradient
    const auroraGradient = defs.append('radialGradient')
      .attr('id', 'aurora-gradient')
      .attr('cx', '50%')
      .attr('cy', '50%')
      .attr('r', '50%')

    auroraGradient.append('stop')
      .attr('offset', '0%')
      .attr('stop-color', '#10b981')
      .attr('stop-opacity', 0.8)

    auroraGradient.append('stop')
      .attr('offset', '50%')
      .attr('stop-color', '#3b82f6')
      .attr('stop-opacity', 0.6)

    auroraGradient.append('stop')
      .attr('offset', '100%')
      .attr('stop-color', '#8b5cf6')
      .attr('stop-opacity', 0.3)

    // Radiation belt gradient
    const radiationGradient = defs.append('radialGradient')
      .attr('id', 'radiation-gradient')
      .attr('cx', '50%')
      .attr('cy', '50%')
      .attr('r', '50%')

    radiationGradient.append('stop')
      .attr('offset', '0%')
      .attr('stop-color', '#fbbf24')
      .attr('stop-opacity', 0.1)

    radiationGradient.append('stop')
      .attr('offset', '70%')
      .attr('stop-color', '#f59e0b')
      .attr('stop-opacity', 0.4)

    radiationGradient.append('stop')
      .attr('offset', '100%')
      .attr('stop-color', '#dc2626')
      .attr('stop-opacity', 0.8)

    // Glow filter
    const filter = defs.append('filter')
      .attr('id', 'glow')
      .attr('x', '-50%')
      .attr('y', '-50%')
      .attr('width', '200%')
      .attr('height', '200%')

    filter.append('feGaussianBlur')
      .attr('stdDeviation', '3')
      .attr('result', 'coloredBlur')

    const merge = filter.append('feMerge')
    merge.append('feMergeNode').attr('in', 'coloredBlur')
    merge.append('feMergeNode').attr('in', 'SourceGraphic')
  },

  createFieldLines() {
    const earthRadius = 25
    const fieldLineGroup = this.svg.append('g').attr('class', 'field-lines')

    // Create magnetic field lines with proper dipole geometry
    for (let i = 0; i < 12; i++) {
      const angle = (i * 30) * Math.PI / 180
      const distance = earthRadius + (i + 1) * 15
      
      const fieldLine = {
        angle: angle,
        distance: distance,
        intensity: 1 - (i / 12),
        path: this.calculateDipoleFieldLine(angle, distance)
      }
      
      const pathElement = fieldLineGroup
        .append('path')
        .attr('d', fieldLine.path)
        .attr('stroke', '#3b82f6')
        .attr('stroke-width', fieldLine.intensity * 2)
        .attr('stroke-opacity', fieldLine.intensity * 0.6)
        .attr('fill', 'none')
        .attr('filter', 'url(#glow)')

      fieldLine.element = pathElement
      this.fieldLines.push(fieldLine)
    }

    // Animate field lines
    this.animateFieldLines()
  },

  calculateDipoleFieldLine(angle, distance) {
    const earthRadius = 25
    const points = []
    
    // Calculate dipole field line path
    for (let t = 0; t <= Math.PI; t += 0.1) {
      const r = distance * Math.pow(Math.sin(t), 2)
      const x = this.centerX + r * Math.cos(angle) * Math.cos(t)
      const y = this.centerY + r * Math.sin(t)
      points.push([x, y])
    }

    // Create smooth path
    const line = d3.line()
      .x(d => d[0])
      .y(d => d[1])
      .curve(d3.curveBasis)

    return line(points)
  },

  animateFieldLines() {
    this.fieldLines.forEach((fieldLine, index) => {
      gsap.to(fieldLine.element.node(), {
        strokeDasharray: "10,5",
        strokeDashoffset: -15,
        duration: 3 + index * 0.2,
        repeat: -1,
        ease: "none"
      })
    })
  },

  createRadiationBelts() {
    const radiationGroup = this.svg.append('g').attr('class', 'radiation-belts')

    // Inner Van Allen Belt
    const innerBelt = radiationGroup
      .append('ellipse')
      .attr('cx', this.centerX)
      .attr('cy', this.centerY)
      .attr('rx', 60)
      .attr('ry', 35)
      .attr('fill', 'url(#radiation-gradient)')
      .attr('opacity', 0.3)

    // Outer Van Allen Belt
    const outerBelt = radiationGroup
      .append('ellipse')
      .attr('cx', this.centerX)
      .attr('cy', this.centerY)
      .attr('rx', 120)
      .attr('ry', 70)
      .attr('fill', 'url(#radiation-gradient)')
      .attr('opacity', 0.2)

    // Animate radiation belts
    gsap.to(innerBelt.node(), {
      opacity: 0.6,
      duration: 2,
      repeat: -1,
      yoyo: true,
      ease: "power2.inOut"
    })

    gsap.to(outerBelt.node(), {
      opacity: 0.4,
      duration: 3,
      repeat: -1,
      yoyo: true,
      ease: "power2.inOut"
    })
  },

  createParticleSystem() {
    const particleCount = 200
    
    for (let i = 0; i < particleCount; i++) {
      this.particles.push({
        x: Math.random() * this.width,
        y: Math.random() * this.height,
        vx: (Math.random() - 0.5) * 2,
        vy: (Math.random() - 0.5) * 2,
        size: Math.random() * 3 + 1,
        color: this.getParticleColor(),
        life: 1,
        type: Math.random() < 0.3 ? 'proton' : 'electron'
      })
    }
  },

  getParticleColor() {
    const colors = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6']
    return colors[Math.floor(Math.random() * colors.length)]
  },

  updateParticles(deltaTime) {
    const earthX = this.centerX
    const earthY = this.centerY
    const earthRadius = 25

    this.particles.forEach(particle => {
      // Calculate magnetic field influence
      const dx = particle.x - earthX
      const dy = particle.y - earthY
      const distance = Math.sqrt(dx * dx + dy * dy)
      
      if (distance > earthRadius) {
        // Lorentz force simulation
        const fieldStrength = 1000 / (distance * distance)
        const fieldAngle = Math.atan2(dy, dx)
        
        // Charged particle motion in magnetic field
        if (particle.type === 'electron') {
          particle.vx += Math.sin(fieldAngle) * fieldStrength * deltaTime
          particle.vy -= Math.cos(fieldAngle) * fieldStrength * deltaTime
        } else {
          particle.vx -= Math.sin(fieldAngle) * fieldStrength * deltaTime
          particle.vy += Math.cos(fieldAngle) * fieldStrength * deltaTime
        }
      }

      // Update position
      particle.x += particle.vx * deltaTime * 60
      particle.y += particle.vy * deltaTime * 60

      // Boundary conditions
      if (particle.x < 0 || particle.x > this.width) particle.vx *= -0.8
      if (particle.y < 0 || particle.y > this.height) particle.vy *= -0.8

      // Keep particles in bounds
      particle.x = Math.max(0, Math.min(this.width, particle.x))
      particle.y = Math.max(0, Math.min(this.height, particle.y))

      // Damping
      particle.vx *= 0.999
      particle.vy *= 0.999
    })
  },

  renderParticles() {
    this.ctx.clearRect(0, 0, this.width, this.height)
    
    this.particles.forEach(particle => {
      this.ctx.globalAlpha = particle.life
      this.ctx.fillStyle = particle.color
      this.ctx.beginPath()
      this.ctx.arc(particle.x, particle.y, particle.size, 0, Math.PI * 2)
      this.ctx.fill()

      // Add glow effect
      this.ctx.shadowColor = particle.color
      this.ctx.shadowBlur = particle.size * 2
      this.ctx.fill()
      this.ctx.shadowBlur = 0
    })
  },

  createAuroraEffect(kpIndex) {
    const auroraGroup = this.svg.select('.aurora') || this.svg.append('g').attr('class', 'aurora')
    auroraGroup.selectAll('*').remove()

    if (kpIndex >= 2) {
      const auroraRadius = 50 + kpIndex * 10
      const intensity = Math.min(1, kpIndex / 9)

      const aurora = auroraGroup
        .append('ellipse')
        .attr('cx', this.centerX)
        .attr('cy', this.centerY)
        .attr('rx', auroraRadius)
        .attr('ry', auroraRadius * 0.6)
        .attr('fill', 'url(#aurora-gradient)')
        .attr('opacity', 0)

      gsap.to(aurora.node(), {
        opacity: intensity,
        duration: 1,
        ease: "power2.out"
      })

      // Add aurora curtain effects
      for (let i = 0; i < 5; i++) {
        const curtain = auroraGroup
          .append('path')
          .attr('d', this.createAuroraCurtain(i))
          .attr('stroke', i % 2 === 0 ? '#10b981' : '#3b82f6')
          .attr('stroke-width', 2)
          .attr('stroke-opacity', 0)
          .attr('fill', 'none')

        gsap.to(curtain.node(), {
          strokeOpacity: intensity * 0.8,
          duration: 1 + i * 0.2,
          ease: "power2.out"
        })

        // Animate curtain movement
        gsap.to(curtain.node(), {
          strokeDasharray: "5,5",
          strokeDashoffset: -10,
          duration: 2 + i * 0.5,
          repeat: -1,
          ease: "none"
        })
      }
    }
  },

  createAuroraCurtain(index) {
    const baseRadius = 45 + index * 8
    const points = []
    
    for (let angle = 0; angle <= Math.PI * 2; angle += 0.2) {
      const noise = Math.sin(angle * 3 + index) * 5
      const r = baseRadius + noise
      const x = this.centerX + r * Math.cos(angle)
      const y = this.centerY + r * Math.sin(angle) * 0.6
      points.push([x, y])
    }

    const line = d3.line()
      .x(d => d[0])
      .y(d => d[1])
      .curve(d3.curveBasis)

    return line(points)
  },

  updateAnimationParams(kpIndex, solarWindSpeed, severity) {
    // Update particle behavior based on space weather
    const intensity = kpIndex / 9
    const windFactor = solarWindSpeed / 400

    this.particles.forEach(particle => {
      particle.vx *= windFactor
      particle.size = (Math.random() * 3 + 1) * (1 + intensity * 0.5)
    })

    // Update field line animations
    this.fieldLines.forEach((fieldLine, index) => {
      const newIntensity = fieldLine.intensity * (1 + intensity)
      fieldLine.element
        .attr('stroke-width', newIntensity * 2)
        .attr('stroke-opacity', newIntensity * 0.8)
    })

    // Create aurora effects
    this.createAuroraEffect(kpIndex)

    // Update radiation belt intensity
    const radiationBelts = this.svg.selectAll('.radiation-belts ellipse')
    radiationBelts.attr('opacity', 0.2 + intensity * 0.4)
  },

  startAnimation() {
    const animate = (currentTime) => {
      const deltaTime = (currentTime - this.lastTime) / 1000
      this.lastTime = currentTime

      if (deltaTime < 0.1) { // Cap delta time to prevent large jumps
        this.updateParticles(deltaTime)
        this.renderParticles()
      }

      this.animationId = requestAnimationFrame(animate)
    }

    this.animationId = requestAnimationFrame(animate)
  },

  setupResizeObserver() {
    this.resizeObserver = new ResizeObserver(entries => {
      for (let entry of entries) {
        this.handleResize()
      }
    })
    
    this.resizeObserver.observe(this.el)
  },

  handleResize() {
    const container = this.el.querySelector('.magnetosphere-container')
    if (!container) return

    this.width = container.offsetWidth
    this.height = container.offsetHeight
    this.centerX = this.width / 2
    this.centerY = this.height / 2

    this.svg.attr('width', this.width).attr('height', this.height)
    this.canvas.attr('width', this.width).attr('height', this.height)

    // Recreate elements with new dimensions
    this.svg.selectAll('*').remove()
    this.setupGradients()
    this.createFieldLines()
    this.createRadiationBelts()
  },

  cleanup() {
    if (this.animationId) {
      cancelAnimationFrame(this.animationId)
    }
    
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }

    gsap.killTweensOf("*")
  }
}