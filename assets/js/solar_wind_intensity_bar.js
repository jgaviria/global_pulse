import * as d3 from 'd3'

export const SolarWindIntensityBar = {
  mounted() {
    this.initializeBar()
    this.updateIndicator()
  },

  updated() {
    this.updateIndicator()
  },

  initializeBar() {
    const width = 48
    const height = 96
    
    // Create SVG
    this.svg = d3.select(this.el)
      .append('svg')
      .attr('width', width)
      .attr('height', height)
      .style('display', 'block')
    
    // Create gradient
    const defs = this.svg.append('defs')
    const gradient = defs.append('linearGradient')
      .attr('id', 'speed-bar-gradient')
      .attr('x1', '0%')
      .attr('y1', '100%')
      .attr('x2', '0%')
      .attr('y2', '0%')
    
    // Solar wind speed colors (200-800 km/s)
    const colors = [
      { offset: '0%', color: '#009900' },     // 200 km/s - Very low
      { offset: '17%', color: '#00ff00' },    // 300 km/s - Low
      { offset: '33%', color: '#66ff00' },    // 400 km/s - Normal
      { offset: '50%', color: '#ffff00' },    // 500 km/s - Elevated
      { offset: '67%', color: '#ff9900' },    // 600 km/s - Strong
      { offset: '83%', color: '#ff6600' },    // 700 km/s - Severe
      { offset: '100%', color: '#ff0000' }    // 800 km/s - Extreme
    ]
    
    colors.forEach(stop => {
      gradient.append('stop')
        .attr('offset', stop.offset)
        .attr('stop-color', stop.color)
    })
    
    // Background
    this.svg.append('rect')
      .attr('x', 0)
      .attr('y', 0)
      .attr('width', width)
      .attr('height', height)
      .attr('fill', '#1a1a1a')
      .attr('stroke', '#333')
      .attr('rx', 2)
    
    // Gradient bar
    this.svg.append('rect')
      .attr('x', 2)
      .attr('y', 2)
      .attr('width', width - 4)
      .attr('height', height - 4)
      .attr('fill', 'url(#speed-bar-gradient)')
      .attr('opacity', 0.8)
      .attr('rx', 2)
    
    // Scale marks (200, 400, 600, 800 km/s)
    const marks = [200, 400, 600, 800]
    marks.forEach(speed => {
      const y = height - ((speed - 200) / 600) * height
      
      // Tick mark
      this.svg.append('line')
        .attr('x1', 0)
        .attr('x2', 5)
        .attr('y1', y)
        .attr('y2', y)
        .attr('stroke', '#666')
        .attr('stroke-width', 1)
      
      // Label (abbreviated)
      if (speed % 400 === 0) {
        this.svg.append('text')
          .attr('x', 8)
          .attr('y', y + 3)
          .attr('fill', '#999')
          .attr('font-size', '8px')
          .text(speed)
      }
    })
    
    // Title
    this.svg.append('text')
      .attr('x', width / 2)
      .attr('y', height + 12)
      .attr('text-anchor', 'middle')
      .attr('fill', '#999')
      .attr('font-size', '9px')
      .text('km/s')
    
    // Indicator group
    this.indicator = this.svg.append('g')
      .attr('class', 'speed-indicator')
    
    // Indicator line
    this.indicatorLine = this.indicator.append('line')
      .attr('x1', 0)
      .attr('x2', width)
      .attr('stroke', '#ffffff')
      .attr('stroke-width', 2)
    
    // Indicator triangle
    this.indicatorArrow = this.indicator.append('path')
      .attr('d', 'M 0,0 L 6,0 L 3,-5 Z')
      .attr('fill', '#ffffff')
  },

  updateIndicator() {
    try {
      if (!this.indicatorLine || !this.indicatorArrow) {
        // Reinitialize if elements are missing
        this.initializeBar()
        return
      }
      
      const speed = parseFloat(this.el.dataset.solarWindSpeed) || 400
      const height = 96
      const normalizedSpeed = Math.max(200, Math.min(800, speed))
      const y = height - ((normalizedSpeed - 200) / 600) * height
      
      // Animate indicator to new position
      this.indicatorLine
        .transition()
        .duration(1000)
        .attr('y1', y)
        .attr('y2', y)
      
      this.indicatorArrow
        .transition()
        .duration(1000)
        .attr('transform', `translate(${42}, ${y})`)
    } catch (error) {
      console.error('Error updating Solar Wind indicator:', error)
    }
  }
}