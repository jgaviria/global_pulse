import * as d3 from 'd3'

export const KPIntensityBar = {
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
      .attr('id', 'kp-bar-gradient')
      .attr('x1', '0%')
      .attr('y1', '100%')
      .attr('x2', '0%')
      .attr('y2', '0%')
    
    // KP scale colors (0-9)
    const colors = [
      { offset: '0%', color: '#009900' },     // 0 - Extremely quiet
      { offset: '22%', color: '#00ff00' },    // 2 - Quiet
      { offset: '44%', color: '#ffff00' },    // 4 - Active
      { offset: '56%', color: '#ffcc00' },    // 5 - Minor storm
      { offset: '67%', color: '#ff9900' },    // 6 - Moderate storm
      { offset: '78%', color: '#ff6600' },    // 7 - Strong storm
      { offset: '89%', color: '#ff3300' },    // 8 - Severe storm
      { offset: '100%', color: '#ff0000' }    // 9 - Extreme storm
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
      .attr('fill', 'url(#kp-bar-gradient)')
      .attr('opacity', 0.8)
      .attr('rx', 2)
    
    // Scale marks
    for (let kp = 0; kp <= 9; kp += 3) {
      const y = height - (kp / 9) * height
      
      // Tick mark
      this.svg.append('line')
        .attr('x1', 0)
        .attr('x2', 5)
        .attr('y1', y)
        .attr('y2', y)
        .attr('stroke', '#666')
        .attr('stroke-width', 1)
      
      // Label
      this.svg.append('text')
        .attr('x', 8)
        .attr('y', y + 3)
        .attr('fill', '#999')
        .attr('font-size', '9px')
        .text(kp)
    }
    
    // Title
    this.svg.append('text')
      .attr('x', width / 2)
      .attr('y', height + 12)
      .attr('text-anchor', 'middle')
      .attr('fill', '#999')
      .attr('font-size', '10px')
      .text('KP')
    
    // Indicator group
    this.indicator = this.svg.append('g')
      .attr('class', 'kp-indicator')
    
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
      
      const kpIndex = parseFloat(this.el.dataset.kpIndex) || 0
      const height = 96
      const y = height - (kpIndex / 9) * height
      
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
      console.error('Error updating KP indicator:', error)
    }
  }
}