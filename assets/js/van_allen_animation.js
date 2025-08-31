import * as d3 from 'd3'
import { gsap } from 'gsap'

export const MagnetosphereAnimation = {
  mounted() {
    console.log('Van Allen Radiation Belt Animation mounted')
    this.initializeVisualization()
    this.startAnimation()
  },

  updated() {
    // Don't reinitialize, just update the values
    if (!this.svg || !this.belts) {
      // If elements are missing, reinitialize
      this.initializeVisualization()
      this.startAnimation()
      return
    }
    
    const kpIndex = parseFloat(this.el.dataset.kpIndex) || 3
    const solarWindSpeed = parseFloat(this.el.dataset.solarWindSpeed) || 400
    const severity = this.el.dataset.severity || 'Minor'
    
    console.log('Updating Van Allen belts - KP:', kpIndex, 'Severity:', severity)
    this.updateBeltIntensity(kpIndex, severity)
  },

  destroyed() {
    this.cleanup()
  },

  initializeVisualization() {
    // Check if already initialized
    if (this.svg) {
      return  // Already initialized, don't recreate
    }
    
    // Clear any existing content
    this.el.innerHTML = ''
    
    // Add CSS animation for Earth rotation
    this.addEarthRotationCSS()
    
    this.width = this.el.offsetWidth
    this.height = this.el.offsetHeight
    this.centerX = this.width / 2
    this.centerY = this.height / 2

    // Create main SVG with black starfield background and increased height
    this.svg = d3.select(this.el)
      .append('svg')
      .attr('width', this.width)
      .attr('height', this.height * 1.5)  // Increase height by 50%
      .style('position', 'absolute')
      .style('top', 0)
      .style('left', 0)
      .style('background', '#000011')

    // Create canvas for particle effects with increased height
    this.canvas = d3.select(this.el)
      .append('canvas')
      .attr('width', this.width)
      .attr('height', this.height * 1.5)  // Increase height by 50%
      .style('position', 'absolute')
      .style('top', 0)
      .style('left', 0)
      .style('z-index', 5)

    this.ctx = this.canvas.node().getContext('2d')

    this.setupGradients()
    this.createStarfield()
    this.createFieldLines()
    this.createVanAllenBelts()
    this.createEarth()  // Create Earth last so it appears on top
    // Remove particle system for clean look like reference
  },

  createStarfield() {
    // Add small white dots as stars
    for (let i = 0; i < 100; i++) {
      this.svg.append('circle')
        .attr('cx', Math.random() * this.width)
        .attr('cy', Math.random() * this.height)
        .attr('r', Math.random() * 1.5 + 0.5)
        .attr('fill', '#ffffff')
        .attr('opacity', Math.random() * 0.8 + 0.2)
    }
  },

  setupGradients() {
    const defs = this.svg.append('defs')

    // Create gradients matching the scientific Van Allen belt color progression
    const gradients = [
      { id: 'innerBelt', colors: ['#0033ff', '#0066ff'] },      // Deep blue (innermost)
      { id: 'innerMid', colors: ['#0099ff', '#00ccff'] },       // Cyan
      { id: 'middleBelt', colors: ['#00ff99', '#66ff66'] },     // Bright green
      { id: 'outerMid', colors: ['#ccff00', '#ffff00'] },       // Yellow-green to yellow
      { id: 'outerBelt', colors: ['#ff9900', '#ff6600'] },      // Orange
      { id: 'outermost', colors: ['#ff3300', '#ff0000'] }       // Red (outermost)
    ]

    gradients.forEach(grad => {
      const gradient = defs.append('radialGradient')
        .attr('id', grad.id)
        .attr('cx', '50%')
        .attr('cy', '50%')
        .attr('r', '70%')

      gradient.append('stop')
        .attr('offset', '0%')
        .attr('stop-color', grad.colors[0])
        .attr('stop-opacity', 0.9)

      gradient.append('stop')
        .attr('offset', '100%')
        .attr('stop-color', grad.colors[1])
        .attr('stop-opacity', 0.9)
    })

    // Earth gradient
    const earthGradient = defs.append('radialGradient')
      .attr('id', 'earthGradient')
      .attr('cx', '30%')
      .attr('cy', '30%')
      .attr('r', '70%')

    earthGradient.append('stop')
      .attr('offset', '0%')
      .attr('stop-color', '#4a90e2')

    earthGradient.append('stop')
      .attr('offset', '70%')
      .attr('stop-color', '#2c3e50')

    earthGradient.append('stop')
      .attr('offset', '100%')
      .attr('stop-color', '#1a1a1a')
  },

  createEarth() {
    // Create Earth AFTER the belts so it appears on top
    this.earthGroup = this.svg.append('g').attr('class', 'earth-group')
    
    // Use the same Earth emoji as the earthquake section - made bigger (static)
    this.earth = this.earthGroup.append('text')
      .attr('x', this.centerX)
      .attr('y', this.centerY)
      .attr('text-anchor', 'middle')
      .attr('dominant-baseline', 'central')
      .attr('font-size', this.width * 0.12 + 'px')  // Increased from 0.08 to 0.12
      .text('🌍')
      .attr('class', 'earth-emoji')
      
    // Add subtle glow effect around Earth
    this.earthGroup.append('circle')
      .attr('cx', this.centerX)
      .attr('cy', this.centerY)
      .attr('r', this.width * 0.07)  // Increased from 0.05 to 0.07 to match bigger Earth
      .attr('fill', 'none')
      .attr('stroke', '#4FC3F7')
      .attr('stroke-width', 1)
      .attr('opacity', 0.3)
      .attr('class', 'earth-glow')
  },

  createVanAllenBelts() {
    this.beltGroup = this.svg.append('g').attr('class', 'van-allen-belts')

    // Create exact belt structure matching scientific Van Allen belt progression
    const beltLayers = [
      { rx: this.width * 0.40, ry: this.height * 0.24, fill: 'url(#outermost)', opacity: 0.9 },  // Red (outermost)
      { rx: this.width * 0.36, ry: this.height * 0.22, fill: 'url(#outerBelt)', opacity: 0.95 }, // Orange
      { rx: this.width * 0.32, ry: this.height * 0.20, fill: 'url(#outerMid)', opacity: 0.95 },  // Yellow
      { rx: this.width * 0.28, ry: this.height * 0.18, fill: 'url(#middleBelt)', opacity: 0.95 }, // Green
      { rx: this.width * 0.24, ry: this.height * 0.16, fill: 'url(#innerMid)', opacity: 0.95 },  // Cyan
      { rx: this.width * 0.20, ry: this.height * 0.14, fill: 'url(#innerBelt)', opacity: 0.95 }, // Deep blue
      { rx: this.width * 0.16, ry: this.height * 0.12, fill: 'url(#innerBelt)', opacity: 0.9 },  // Inner blue
      { rx: this.width * 0.12, ry: this.height * 0.10, fill: 'url(#innerBelt)', opacity: 0.85 }  // Innermost blue
    ]

    this.belts = []
    beltLayers.forEach((layer, index) => {
      const belt = this.beltGroup.append('ellipse')
        .attr('cx', this.centerX)
        .attr('cy', this.centerY)
        .attr('rx', layer.rx)
        .attr('ry', layer.ry)
        .attr('fill', layer.fill)
        .attr('opacity', layer.opacity)
        .attr('stroke', 'none')
      
      this.belts.push(belt)
    })

    // Create the central void around Earth
    const innerHole = this.beltGroup.append('ellipse')
      .attr('cx', this.centerX)
      .attr('cy', this.centerY)
      .attr('rx', this.width * 0.11)
      .attr('ry', this.height * 0.08)
      .attr('fill', '#000011')
      .attr('opacity', 1.0)

    // No animation for clean static look like reference
  },

  createFieldLines() {
    console.log('Creating magnetic field lines...')
    this.fieldGroup = this.svg.append('g').attr('class', 'field-lines')

    // Create visible static dipole magnetic field lines
    const numLines = 16  // Uniform distribution around Earth
    this.fieldLines = []

    for (let i = 0; i < numLines; i++) {
      const angle = (i * 360 / numLines) * Math.PI / 180
      const path = this.createStaticDipoleFieldLine(angle)
      
      const fieldLine = this.fieldGroup.append('path')
        .attr('d', path)
        .attr('stroke', '#ffffff')  // Bright white for visibility
        .attr('stroke-width', 0.8)  // Thinner lines
        .attr('fill', 'none')
        .attr('opacity', 0.6)       // Slightly less opaque
        .attr('stroke-linecap', 'round')
        .attr('stroke-dasharray', '2,3')  // Dotted pattern

      this.fieldLines.push(fieldLine)
      console.log(`Created field line ${i + 1}: ${path}`)
    }
    
    console.log(`Total field lines created: ${this.fieldLines.length}`)
  },

  createStaticDipoleFieldLine(angle) {
    const points = []
    const earthRadius = this.width * 0.06
    const maxDistance = this.width * 0.45
    
    // Create classic dipole field lines radiating from poles
    // Start from north pole area
    const startX = this.centerX
    const startY = this.centerY - earthRadius * 0.8
    
    // Create curved field line that loops to south pole
    for (let t = 0; t <= 1; t += 0.05) {
      // Create dipole field line shape using parametric equations
      const r = earthRadius + maxDistance * Math.pow(Math.sin(t * Math.PI), 1.5)
      const theta = t * Math.PI - Math.PI/2  // From -π/2 to π/2
      
      const x = this.centerX + r * Math.sin(angle) * Math.cos(theta)
      const y = this.centerY + r * Math.sin(theta) * 0.7  // Compress vertically
      
      points.push([x, y])
    }

    const line = d3.line()
      .x(d => d[0])
      .y(d => d[1])
      .curve(d3.curveBasis)

    return line(points)
  },

  createIntensityBar() {
    // Create KP Index intensity bar (0-9 scale)
    const barGroup = this.svg.append('g').attr('class', 'intensity-bar')
    const barX = this.width - 60
    const barY = 20
    const barHeight = 120
    const barWidth = 40
    
    // Background
    barGroup.append('rect')
      .attr('x', barX)
      .attr('y', barY)
      .attr('width', barWidth)
      .attr('height', barHeight)
      .attr('fill', '#1a1a1a')
      .attr('stroke', '#333')
      .attr('stroke-width', 1)
      .attr('rx', 3)
    
    // KP scale labels and colors (0-9)
    const kpScale = [
      { value: 9, color: '#ff0000', label: 'G5' },  // Extreme storm
      { value: 8, color: '#ff3300', label: 'G4' },  // Severe storm
      { value: 7, color: '#ff6600', label: 'G3' },  // Strong storm
      { value: 6, color: '#ff9900', label: 'G2' },  // Moderate storm
      { value: 5, color: '#ffcc00', label: 'G1' },  // Minor storm
      { value: 4, color: '#ffff00', label: 'A0' },  // Active
      { value: 3, color: '#66ff00', label: 'U0' },  // Unsettled
      { value: 2, color: '#00ff00', label: 'Q0' },  // Quiet
      { value: 1, color: '#00cc00', label: 'Q0' },  // Very quiet
      { value: 0, color: '#009900', label: 'Q0' }   // Extremely quiet
    ]
    
    // Create gradient for smooth color transition
    const gradientId = 'kpGradient'
    const gradient = this.svg.select('defs').append('linearGradient')
      .attr('id', gradientId)
      .attr('x1', '0%')
      .attr('y1', '100%')
      .attr('x2', '0%')
      .attr('y2', '0%')
    
    kpScale.forEach((item, i) => {
      gradient.append('stop')
        .attr('offset', `${(9 - item.value) * 11.11}%`)
        .attr('stop-color', item.color)
    })
    
    // Filled intensity bar
    barGroup.append('rect')
      .attr('x', barX + 2)
      .attr('y', barY + 2)
      .attr('width', barWidth - 4)
      .attr('height', barHeight - 4)
      .attr('fill', `url(#${gradientId})`)
      .attr('opacity', 0.7)
    
    // Current KP indicator
    const kpIndex = parseFloat(this.el.dataset.kpIndex) || 3
    const indicatorY = barY + barHeight - (kpIndex / 9) * barHeight
    
    this.kpIndicator = barGroup.append('g')
      .attr('class', 'kp-indicator')
    
    // Indicator line
    this.kpIndicator.append('line')
      .attr('x1', barX - 5)
      .attr('x2', barX + barWidth + 5)
      .attr('y1', indicatorY)
      .attr('y2', indicatorY)
      .attr('stroke', '#ffffff')
      .attr('stroke-width', 2)
    
    // Indicator value
    this.kpIndicator.append('text')
      .attr('x', barX - 10)
      .attr('y', indicatorY + 4)
      .attr('text-anchor', 'end')
      .attr('fill', '#ffffff')
      .attr('font-size', '12px')
      .attr('font-weight', 'bold')
      .text(`KP: ${kpIndex.toFixed(1)}`)
    
    // Scale markings
    for (let kp = 0; kp <= 9; kp++) {
      const y = barY + barHeight - (kp / 9) * barHeight
      
      // Tick marks
      barGroup.append('line')
        .attr('x1', barX - 3)
        .attr('x2', barX)
        .attr('y1', y)
        .attr('y2', y)
        .attr('stroke', '#666')
        .attr('stroke-width', 1)
      
      // Labels for major marks
      if (kp % 3 === 0) {
        barGroup.append('text')
          .attr('x', barX - 8)
          .attr('y', y + 3)
          .attr('text-anchor', 'end')
          .attr('fill', '#999')
          .attr('font-size', '10px')
          .text(kp)
      }
    }
    
    // Title
    barGroup.append('text')
      .attr('x', barX + barWidth / 2)
      .attr('y', barY - 5)
      .attr('text-anchor', 'middle')
      .attr('fill', '#ffffff')
      .attr('font-size', '11px')
      .attr('font-weight', 'bold')
      .text('KP INDEX')
  },

  addEarthRotationCSS() {
    // Add keyframe animation for Earth rotation if not already added
    if (!document.getElementById('earth-rotation-style')) {
      const style = document.createElement('style')
      style.id = 'earth-rotation-style'
      style.textContent = `
        @keyframes earthRotation {
          from {
            transform: rotate(0deg);
          }
          to {
            transform: rotate(-360deg);
          }
        }
      `
      document.head.appendChild(style)
    }
  },

  // No particle system needed for clean static look

  getParticleColor() {
    const colors = ['#0066ff', '#00ff66', '#ffff00', '#ff6600', '#ff0000']
    return colors[Math.floor(Math.random() * colors.length)]
  },

  animateVisualization() {
    console.log('Starting Van Allen belt pulsation animations...')
    // Van Allen belt color pulsation animation
    this.belts.forEach((belt, index) => {
      const baseOpacity = parseFloat(belt.attr('opacity'))
      console.log(`Belt ${index}: Base opacity ${baseOpacity}, animating between ${baseOpacity * 0.6} and ${Math.min(baseOpacity * 1.4, 1.0)}`)
      gsap.to(belt.node(), {
        opacity: Math.min(baseOpacity * 1.4, 1.0),  // Cap at 1.0 opacity
        duration: 2.0 + index * 0.3,   // Slower, more dramatic pulsing
        repeat: -1,
        yoyo: true,
        ease: "power2.inOut"
      })
      
      // Add secondary animation for more dynamic pulsing
      gsap.to(belt.node(), {
        opacity: baseOpacity * 0.6,  // Dimmer phase
        duration: 1.0 + index * 0.2,
        repeat: -1,
        yoyo: true,
        ease: "sine.inOut",
        delay: index * 0.1  // Stagger the animations
      })
    })
    
    // Keep Earth stable for now - emoji rotation can be tricky in SVG
    // The Van Allen belt pulsation provides enough visual interest
    
    // Breathing effect for Earth glow
    const earthGlow = this.earthGroup.select('.earth-glow')
    if (earthGlow.node()) {
      gsap.to(earthGlow.node(), {
        r: this.width * 0.06,
        opacity: 0.6,
        duration: 2,
        repeat: -1,
        yoyo: true,
        ease: "power2.inOut"
      })
    }
  },

  // Field lines will rotate slowly via the main animation loop

  updateBeltIntensity(kpIndex, severity) {
    const intensity = Math.min(kpIndex / 9, 1)
    
    // Update KP indicator position
    if (this.kpIndicator) {
      const barY = 20
      const barHeight = 120
      const indicatorY = barY + barHeight - (kpIndex / 9) * barHeight
      
      gsap.to(this.kpIndicator.select('line').node(), {
        attr: { y1: indicatorY, y2: indicatorY },
        duration: 1,
        ease: "power2.inOut"
      })
      
      gsap.to(this.kpIndicator.select('text').node(), {
        y: indicatorY + 4,
        duration: 1,
        ease: "power2.inOut",
        onUpdate: () => {
          this.kpIndicator.select('text').text(`KP: ${kpIndex.toFixed(1)}`)
        }
      })
    }
    
    // Update belt intensity based on KP index
    if (this.belts) {
      this.belts.forEach((belt, index) => {
        const baseOpacity = 0.85 + (intensity * 0.15)
        gsap.to(belt.node(), {
          opacity: baseOpacity,
          duration: 2
        })
      })
    }

    // Update field line intensity
    if (this.fieldLines) {
      this.fieldLines.forEach(line => {
        gsap.to(line.node(), {
          opacity: 0.3 + intensity * 0.4,
          strokeWidth: 0.8 + intensity * 0.4,
          duration: 1
        })
      })
    }
  },

  animateParticles() {
    if (!this.ctx) return

    this.ctx.clearRect(0, 0, this.width, this.height)
    this.ctx.globalCompositeOperation = 'screen'

    this.particles.forEach(particle => {
      // Update particle position
      particle.angle += particle.speed
      
      const beltRadius = particle.belt === 'inner' ? 
        this.width * 0.18 : this.width * 0.28
      const x = this.centerX + (beltRadius + particle.radius * 0.2) * Math.cos(particle.angle)
      const y = this.centerY + (beltRadius + particle.radius * 0.2) * Math.sin(particle.angle) * 0.7

      // Draw particle with proper opacity
      this.ctx.fillStyle = particle.color
      this.ctx.globalAlpha = particle.opacity
      this.ctx.beginPath()
      this.ctx.arc(x, y, particle.size, 0, Math.PI * 2)
      this.ctx.fill()

      // Add subtle glow
      this.ctx.shadowColor = particle.color
      this.ctx.shadowBlur = particle.size * 2
      this.ctx.globalAlpha = particle.opacity * 0.5
      this.ctx.fill()
      this.ctx.shadowBlur = 0
    })

    this.ctx.globalCompositeOperation = 'source-over'
  },

  startAnimation() {
    // Add subtle animations to bring the visualization to life
    this.animateVisualization()
    
    // No field line rotation - keep them static
    this.animationId = null
  },

  setupResizeObserver() {
    this.resizeObserver = new ResizeObserver(() => {
      this.handleResize()
    })
    this.resizeObserver.observe(this.el)
  },

  handleResize() {
    this.width = this.el.offsetWidth
    this.height = this.el.offsetHeight
    this.centerX = this.width / 2
    this.centerY = this.height / 2

    if (this.svg) {
      this.svg.attr('width', this.width).attr('height', this.height)
    }
    if (this.canvas) {
      this.canvas.attr('width', this.width).attr('height', this.height)
    }
  },

  cleanup() {
    try {
      if (this.animationId) {
        cancelAnimationFrame(this.animationId)
        this.animationId = null
      }
      if (this.resizeObserver) {
        this.resizeObserver.disconnect()
        this.resizeObserver = null
      }
      // Kill only tweens related to this component
      if (this.belts) {
        this.belts.forEach(belt => {
          if (belt.node()) gsap.killTweensOf(belt.node())
        })
      }
      if (this.earth && this.earth.node()) {
        gsap.killTweensOf(this.earth.node())
      }
      if (this.fieldLines) {
        this.fieldLines.forEach(line => {
          if (line.node()) gsap.killTweensOf(line.node())
        })
      }
      // Clear references but don't remove DOM elements
      this.svg = null
      this.canvas = null
      this.ctx = null
      this.belts = null
      this.earth = null
      this.fieldLines = null
    } catch (error) {
      console.error('Error during Van Allen cleanup:', error)
    }
  }
}