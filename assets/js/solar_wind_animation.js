import * as d3 from 'd3'
import { gsap } from 'gsap'

export const SolarWindAnimation = {
  mounted() {
    console.log('Solar Wind Stream Animation mounted')
    this.initializeVisualization()
    this.startAnimation()
  },

  updated() {
    // Don't reinitialize, just update the values
    if (!this.svg || !this.streamlines) {
      // If elements are missing, reinitialize
      this.initializeVisualization()
      this.startAnimation()
      return
    }
    
    const speed = parseFloat(this.el.dataset.solarWindSpeed) || 400
    const density = parseFloat(this.el.dataset.solarWindDensity) || 5
    const temperature = parseFloat(this.el.dataset.solarWindTemperature) || 100000
    
    console.log('Updating Solar Wind - Speed:', speed, 'Density:', density, 'Temperature:', temperature)
    this.updateSolarWindIntensity(speed, density, temperature)
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
    
    this.width = this.el.offsetWidth
    this.height = this.el.offsetHeight
    this.centerX = this.width / 2
    this.centerY = this.height / 2

    // Create main SVG
    this.svg = d3.select(this.el)
      .append('svg')
      .attr('width', this.width)
      .attr('height', this.height)
      .style('position', 'absolute')
      .style('top', 0)
      .style('left', 0)
      .style('background', 'transparent')

    // Create canvas for particle effects
    this.canvas = d3.select(this.el)
      .append('canvas')
      .attr('width', this.width)
      .attr('height', this.height)
      .style('position', 'absolute')
      .style('top', 0)
      .style('left', 0)
      .style('z-index', 5)

    this.ctx = this.canvas.node().getContext('2d')

    this.setupGradients()
    this.createSun()  // Create Sun first (background)
    this.createSolarWindStreamlines()
    this.createEarth()
    this.createMagnetosphere()
    this.initializeParticles()
  },

  setupGradients() {
    const defs = this.svg.append('defs')

    // Solar wind flow gradient (yellow to orange)
    const solarWindGradient = defs.append('linearGradient')
      .attr('id', 'solarWindGradient')
      .attr('x1', '0%')
      .attr('y1', '0%')
      .attr('x2', '100%')
      .attr('y2', '0%')

    solarWindGradient.append('stop')
      .attr('offset', '0%')
      .attr('stop-color', '#ffcc00')
      .attr('stop-opacity', 0.8)

    solarWindGradient.append('stop')
      .attr('offset', '70%')
      .attr('stop-color', '#ff6600')
      .attr('stop-opacity', 0.6)

    solarWindGradient.append('stop')
      .attr('offset', '100%')
      .attr('stop-color', '#cc3300')
      .attr('stop-opacity', 0.3)

    // Magnetosphere gradient (blue protective field)
    const magnetosphereGradient = defs.append('radialGradient')
      .attr('id', 'magnetosphereGradient')
      .attr('cx', '50%')
      .attr('cy', '50%')
      .attr('r', '70%')

    magnetosphereGradient.append('stop')
      .attr('offset', '0%')
      .attr('stop-color', '#00ccff')
      .attr('stop-opacity', 0.3)

    magnetosphereGradient.append('stop')
      .attr('offset', '100%')
      .attr('stop-color', '#0066ff')
      .attr('stop-opacity', 0.8)
  },

  createSolarWindStreamlines() {
    this.streamlineGroup = this.svg.append('g').attr('class', 'solar-wind-streamlines')
    this.streamlines = []

    // Create flowing streamlines like in the reference image
    const numStreamlines = 12
    
    for (let i = 0; i < numStreamlines; i++) {
      const yOffset = (i - numStreamlines/2) * (this.height / numStreamlines) * 0.8
      const centerY = this.centerY + yOffset
      
      // Create curved streamline path that flows around Earth's magnetosphere
      const path = this.createStreamlinePath(centerY, i)
      
      const streamline = this.streamlineGroup.append('path')
        .attr('d', path)
        .attr('stroke', 'url(#solarWindGradient)')
        .attr('stroke-width', Math.abs(yOffset) < this.height * 0.15 ? 2 : 1.5) // Thicker lines near center
        .attr('fill', 'none')
        .attr('opacity', Math.abs(yOffset) < this.height * 0.2 ? 0.9 : 0.6)
        .attr('stroke-linecap', 'round')

      this.streamlines.push(streamline)
    }
  },

  createStreamlinePath(centerY, index) {
    const points = []
    const sunX = this.width * 0.05  // Sun position
    const sunRadius = this.width * 0.12
    const earthX = this.width * 0.75  // Earth position
    const earthRadius = this.width * 0.06
    
    // Start from Sun's edge
    for (let x = sunX + sunRadius; x <= this.width; x += 5) {
      let y = centerY
      
      // Expand slightly from Sun
      if (x < sunX + sunRadius * 2) {
        const expansion = (x - sunX - sunRadius) / sunRadius
        y += (centerY - this.centerY) * expansion * 0.3
      }
      
      // Calculate deflection around Earth's magnetosphere
      const distanceToEarth = Math.sqrt((x - earthX) ** 2 + (centerY - this.centerY) ** 2)
      const magnetosphereRadius = earthRadius * 2.5
      
      if (x > earthX - magnetosphereRadius && distanceToEarth < magnetosphereRadius) {
        // Deflect streamlines around magnetosphere
        const deflectionStrength = (magnetosphereRadius - distanceToEarth) / magnetosphereRadius
        const deflectionDirection = centerY > this.centerY ? 1 : -1
        y += deflectionDirection * deflectionStrength * earthRadius * 2
      }
      
      // Add some wave motion for more realistic flow
      y += Math.sin((x * 0.02) + (index * 0.5)) * 8
      
      points.push([x, y])
    }

    const line = d3.line()
      .x(d => d[0])
      .y(d => d[1])
      .curve(d3.curveBasis)

    return line(points)
  },

  createSun() {
    // Sun positioned at left side - much larger than Earth
    // Note: Real Sun is ~109x Earth's diameter, but we'll use artistic license
    const sunX = this.width * 0.05  // Far left edge
    const sunY = this.centerY
    const sunRadius = this.width * 0.12  // Large sun
    
    this.sunGroup = this.svg.append('g').attr('class', 'sun-group')
    
    // Sun gradient
    const sunGradient = this.svg.select('defs').append('radialGradient')
      .attr('id', 'sunGradient')
      .attr('cx', '30%')
      .attr('cy', '30%')
      .attr('r', '70%')
    
    sunGradient.append('stop')
      .attr('offset', '0%')
      .attr('stop-color', '#ffff99')
      .attr('stop-opacity', 1)
    
    sunGradient.append('stop')
      .attr('offset', '50%')
      .attr('stop-color', '#ffcc00')
      .attr('stop-opacity', 1)
    
    sunGradient.append('stop')
      .attr('offset', '100%')
      .attr('stop-color', '#ff6600')
      .attr('stop-opacity', 0.9)
    
    // Sun body
    this.sun = this.sunGroup.append('circle')
      .attr('cx', sunX)
      .attr('cy', sunY)
      .attr('r', sunRadius)
      .attr('fill', 'url(#sunGradient)')
      .attr('filter', 'url(#sunGlow)')
    
    // Sun glow filter
    const filter = this.svg.select('defs').append('filter')
      .attr('id', 'sunGlow')
      .attr('x', '-50%')
      .attr('y', '-50%')
      .attr('width', '200%')
      .attr('height', '200%')
    
    filter.append('feGaussianBlur')
      .attr('stdDeviation', '4')
      .attr('result', 'coloredBlur')
    
    const feMerge = filter.append('feMerge')
    feMerge.append('feMergeNode').attr('in', 'coloredBlur')
    feMerge.append('feMergeNode').attr('in', 'SourceGraphic')
    
    // Corona effect (outer glow)
    this.sunGroup.append('circle')
      .attr('cx', sunX)
      .attr('cy', sunY)
      .attr('r', sunRadius * 1.3)
      .attr('fill', 'none')
      .attr('stroke', '#ff9900')
      .attr('stroke-width', 2)
      .attr('opacity', 0.3)
      .attr('class', 'sun-corona')
    
    // Solar flare spots (optional detail)
    for (let i = 0; i < 3; i++) {
      const angle = Math.random() * Math.PI * 2
      const distance = Math.random() * sunRadius * 0.7
      const spotX = sunX + Math.cos(angle) * distance
      const spotY = sunY + Math.sin(angle) * distance
      
      this.sunGroup.append('circle')
        .attr('cx', spotX)
        .attr('cy', spotY)
        .attr('r', sunRadius * 0.05)
        .attr('fill', '#cc3300')
        .attr('opacity', 0.6)
        .attr('class', 'sun-spot')
    }
  },

  createEarth() {
    // Earth positioned at right side - much smaller than Sun
    const earthX = this.width * 0.75
    const earthY = this.centerY
    
    this.earthGroup = this.svg.append('g').attr('class', 'earth-group')
    
    this.earth = this.earthGroup.append('text')
      .attr('x', earthX)
      .attr('y', earthY)
      .attr('text-anchor', 'middle')
      .attr('dominant-baseline', 'central')
      .attr('font-size', this.width * 0.06 + 'px')  // Smaller Earth compared to Sun
      .text('🌍')
      .attr('class', 'earth-emoji')
  },

  createMagnetosphere() {
    // Create Earth's protective magnetosphere field
    const earthX = this.width * 0.75
    const earthY = this.centerY
    const magnetosphereRadius = this.width * 0.15
    
    this.magnetosphereGroup = this.svg.append('g').attr('class', 'magnetosphere')
    
    // Magnetosphere bow shock
    this.bowShock = this.magnetosphereGroup.append('ellipse')
      .attr('cx', earthX - this.width * 0.05)
      .attr('cy', earthY)
      .attr('rx', magnetosphereRadius * 1.2)
      .attr('ry', magnetosphereRadius * 0.8)
      .attr('fill', 'url(#magnetosphereGradient)')
      .attr('opacity', 0.4)
      .attr('stroke', '#00ccff')
      .attr('stroke-width', 1)
      .attr('stroke-opacity', 0.6)
  },

  createIntensityBar() {
    // Create Solar Wind Speed intensity bar (200-800+ km/s scale)
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
    
    // Solar wind speed scale colors (km/s)
    // Based on NOAA Space Weather Scale
    const speedScale = [
      { value: 800, color: '#ff0000', label: 'Extreme' },  // > 800 km/s
      { value: 700, color: '#ff3300', label: 'Severe' },   // 700-800 km/s
      { value: 600, color: '#ff6600', label: 'Strong' },   // 600-700 km/s
      { value: 500, color: '#ff9900', label: 'Moderate' }, // 500-600 km/s
      { value: 450, color: '#ffcc00', label: 'Elevated' }, // 450-500 km/s
      { value: 400, color: '#ffff00', label: 'Normal' },   // 400-450 km/s (typical)
      { value: 350, color: '#66ff00', label: 'Quiet' },    // 350-400 km/s
      { value: 300, color: '#00ff00', label: 'Low' },      // 300-350 km/s
      { value: 250, color: '#00cc00', label: 'Very Low' }, // 250-300 km/s
      { value: 200, color: '#009900', label: 'Min' }       // < 250 km/s
    ]
    
    // Create gradient for smooth color transition
    const gradientId = 'speedGradient'
    const gradient = this.svg.select('defs').append('linearGradient')
      .attr('id', gradientId)
      .attr('x1', '0%')
      .attr('y1', '100%')
      .attr('x2', '0%')
      .attr('y2', '0%')
    
    speedScale.forEach((item, i) => {
      const offset = ((item.value - 200) / 600) * 100  // Normalize to 200-800 range
      gradient.append('stop')
        .attr('offset', `${offset}%`)
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
    
    // Current speed indicator
    const speed = parseFloat(this.el.dataset.solarWindSpeed) || 400
    const normalizedSpeed = Math.max(200, Math.min(800, speed)) // Clamp between 200-800
    const indicatorY = barY + barHeight - ((normalizedSpeed - 200) / 600) * barHeight
    
    this.speedIndicator = barGroup.append('g')
      .attr('class', 'speed-indicator')
    
    // Indicator line
    this.speedIndicator.append('line')
      .attr('x1', barX - 5)
      .attr('x2', barX + barWidth + 5)
      .attr('y1', indicatorY)
      .attr('y2', indicatorY)
      .attr('stroke', '#ffffff')
      .attr('stroke-width', 2)
    
    // Indicator value
    this.speedIndicator.append('text')
      .attr('x', barX - 10)
      .attr('y', indicatorY + 4)
      .attr('text-anchor', 'end')
      .attr('fill', '#ffffff')
      .attr('font-size', '11px')
      .attr('font-weight', 'bold')
      .text(`${Math.round(speed)}`)
    
    // Scale markings (200, 400, 600, 800 km/s)
    const scaleMarks = [200, 300, 400, 500, 600, 700, 800]
    scaleMarks.forEach(mark => {
      const y = barY + barHeight - ((mark - 200) / 600) * barHeight
      
      // Tick marks
      barGroup.append('line')
        .attr('x1', barX - 3)
        .attr('x2', barX)
        .attr('y1', y)
        .attr('y2', y)
        .attr('stroke', '#666')
        .attr('stroke-width', 1)
      
      // Labels for major marks
      if (mark % 200 === 0) {
        barGroup.append('text')
          .attr('x', barX - 8)
          .attr('y', y + 3)
          .attr('text-anchor', 'end')
          .attr('fill', '#999')
          .attr('font-size', '9px')
          .text(mark)
      }
    })
    
    // Title
    barGroup.append('text')
      .attr('x', barX + barWidth / 2)
      .attr('y', barY - 5)
      .attr('text-anchor', 'middle')
      .attr('fill', '#ffffff')
      .attr('font-size', '11px')
      .attr('font-weight', 'bold')
      .text('SPEED km/s')
  },

  initializeParticles() {
    this.particles = []
    const numParticles = 60
    const sunX = this.width * 0.05
    const sunRadius = this.width * 0.12
    
    for (let i = 0; i < numParticles; i++) {
      const angle = Math.random() * Math.PI * 2
      const startRadius = sunRadius + Math.random() * 10
      
      this.particles.push({
        x: sunX + Math.cos(angle) * startRadius, // Start from Sun's surface
        y: this.centerY + Math.sin(angle) * startRadius * 0.7,
        speed: 1 + Math.random() * 2,
        size: 1 + Math.random() * 2,
        opacity: 0.3 + Math.random() * 0.7,
        color: this.getParticleColor(),
        streamline: Math.floor(Math.random() * this.streamlines.length)
      })
    }
  },

  getParticleColor() {
    const colors = ['#ffcc00', '#ff9900', '#ff6600', '#ff3300']
    return colors[Math.floor(Math.random() * colors.length)]
  },

  startAnimation() {
    this.animateSun()
    this.animateStreamlines()
    this.animateMagnetosphere()
    this.animateParticles()
  },
  
  animateSun() {
    // Animate sun corona pulsing
    if (this.sunGroup) {
      const corona = this.sunGroup.select('.sun-corona')
      gsap.to(corona.node(), {
        r: this.width * 0.12 * 1.4,  // Expand corona
        opacity: 0.5,
        duration: 3,
        repeat: -1,
        yoyo: true,
        ease: "power2.inOut"
      })
      
      // Animate sun spots rotation
      const spots = this.sunGroup.selectAll('.sun-spot')
      spots.each(function(d, i) {
        gsap.to(this, {
          opacity: 0.3 + Math.random() * 0.5,
          duration: 2 + i * 0.5,
          repeat: -1,
          yoyo: true,
          ease: "sine.inOut"
        })
      })
    }
  },

  animateStreamlines() {
    // Subtle pulsation of streamlines
    this.streamlines.forEach((streamline, index) => {
      gsap.to(streamline.node(), {
        opacity: 0.3 + Math.random() * 0.6,
        duration: 2 + index * 0.1,
        repeat: -1,
        yoyo: true,
        ease: "power2.inOut"
      })
    })
  },

  animateMagnetosphere() {
    // Breathing effect for magnetosphere
    if (this.bowShock) {
      gsap.to(this.bowShock.node(), {
        opacity: 0.6,
        duration: 3,
        repeat: -1,
        yoyo: true,
        ease: "power2.inOut"
      })
    }
  },

  animateParticles() {
    const sunX = this.width * 0.05
    const sunRadius = this.width * 0.12
    
    const animate = () => {
      try {
        if (!this.ctx || !this.particles) return
        
        this.ctx.clearRect(0, 0, this.width, this.height)
        this.ctx.globalCompositeOperation = 'screen'

        this.particles.forEach(particle => {
        // Move particle along flow
        particle.x += particle.speed
        
        // Reset particle when it goes off screen - emit from Sun
        if (particle.x > this.width + 10) {
          const angle = Math.random() * Math.PI * 2
          const startRadius = sunRadius + Math.random() * 10
          particle.x = sunX + Math.cos(angle) * startRadius
          particle.y = this.centerY + Math.sin(angle) * startRadius * 0.7
        }

        // Apply deflection near Earth
        const earthX = this.width * 0.75
        const earthY = this.centerY
        const distanceToEarth = Math.sqrt((particle.x - earthX) ** 2 + (particle.y - earthY) ** 2)
        const magnetosphereRadius = this.width * 0.15
        
        if (distanceToEarth < magnetosphereRadius) {
          const deflectionDirection = particle.y > earthY ? 1 : -1
          particle.y += deflectionDirection * 2
        }

        // Draw particle
        this.ctx.fillStyle = particle.color
        this.ctx.globalAlpha = particle.opacity
        this.ctx.beginPath()
        this.ctx.arc(particle.x, particle.y, particle.size, 0, Math.PI * 2)
        this.ctx.fill()

        // Add trail effect
        this.ctx.shadowColor = particle.color
        this.ctx.shadowBlur = particle.size * 3
        this.ctx.globalAlpha = particle.opacity * 0.3
        this.ctx.fill()
        this.ctx.shadowBlur = 0
      })

        this.ctx.globalCompositeOperation = 'source-over'
        this.animationId = requestAnimationFrame(animate)
      } catch (error) {
        console.error('Error in Solar Wind particle animation:', error)
      }
    }
    
    animate()
  },

  updateSolarWindIntensity(speed, density, temperature) {
    // Update speed indicator position
    if (this.speedIndicator) {
      const barY = 20
      const barHeight = 120
      const normalizedSpeed = Math.max(200, Math.min(800, speed)) // Clamp between 200-800
      const indicatorY = barY + barHeight - ((normalizedSpeed - 200) / 600) * barHeight
      
      gsap.to(this.speedIndicator.select('line').node(), {
        attr: { y1: indicatorY, y2: indicatorY },
        duration: 1,
        ease: "power2.inOut"
      })
      
      gsap.to(this.speedIndicator.select('text').node(), {
        y: indicatorY + 4,
        duration: 1,
        ease: "power2.inOut",
        onUpdate: () => {
          this.speedIndicator.select('text').text(`${Math.round(speed)}`)
        }
      })
    }
    
    // Update particle speed and count based on real data
    const speedMultiplier = Math.max(speed / 500, 0.5)
    
    this.particles.forEach(particle => {
      particle.speed = (1 + Math.random() * 2) * speedMultiplier
    })

    // Update streamline opacity based on density
    const densityOpacity = Math.min(density / 15, 1)
    this.streamlines.forEach(streamline => {
      gsap.to(streamline.node(), {
        opacity: 0.4 + densityOpacity * 0.5,
        duration: 1
      })
    })
    
    // Update magnetosphere intensity based on solar wind pressure
    if (this.bowShock) {
      const pressure = (density * speed * speed) / 1000000 // Simple pressure calculation
      const pressureOpacity = Math.min(0.3 + pressure * 0.1, 0.8)
      gsap.to(this.bowShock.node(), {
        opacity: pressureOpacity,
        duration: 1
      })
    }
  },

  cleanup() {
    try {
      if (this.animationId) {
        cancelAnimationFrame(this.animationId)
        this.animationId = null
      }
      // Kill only tweens related to this component
      if (this.streamlines) {
        this.streamlines.forEach(streamline => {
          if (streamline.node()) gsap.killTweensOf(streamline.node())
        })
      }
      if (this.bowShock && this.bowShock.node()) {
        gsap.killTweensOf(this.bowShock.node())
      }
      if (this.sunGroup) {
        const corona = this.sunGroup.select('.sun-corona')
        if (corona.node()) {
          gsap.killTweensOf(corona.node())
        }
        const spots = this.sunGroup.selectAll('.sun-spot')
        spots.each(function() {
          gsap.killTweensOf(this)
        })
      }
      // Clear references but don't remove DOM elements
      this.particles = []
      this.svg = null
      this.canvas = null
      this.ctx = null
      this.streamlines = null
      this.bowShock = null
      this.sunGroup = null
    } catch (error) {
      console.error('Error during Solar Wind cleanup:', error)
    }
  }
}