// Volatility Index Chart Component

export const VolatilityChart = {
  mounted() {
    console.log('VolatilityChart mounted');
    this.initializeChart();
    this.startUpdates();
  },

  updated() {
    // Ignore LiveView updates to maintain smooth animation
    return false;
  },

  destroyed() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
    }
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
    }
  },

  initializeChart() {
    const canvas = this.el.querySelector('#volatility-canvas');
    if (!canvas) {
      console.error('Volatility canvas not found');
      return;
    }

    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    
    // Store original canvas size
    this.setupCanvasSize();
    
    // Store these values to prevent resizing
    this.lockedWidth = this.displayWidth;
    this.lockedHeight = this.displayHeight;
    
    // Initialize volatility data (VIX equivalent, 10-80 range)
    this.dataPoints = 30;
    this.volatilityData = [];
    this.timeLabels = [];
    
    // Starting volatility around 22 (normal market conditions)
    const baseVolatility = 22;
    const now = Date.now();
    
    for (let i = this.dataPoints - 1; i >= 0; i--) {
      const variation = (Math.random() - 0.5) * 12; // ±6 point variation
      this.volatilityData.push(Math.max(10, Math.min(80, baseVolatility + variation)));
      this.timeLabels.push(new Date(now - i * 5000)); // Every 5 seconds
    }
    
    this.currentVolatility = this.volatilityData[this.volatilityData.length - 1];
    this.drawChart();
  },

  setupCanvasSize() {
    if (!this.canvas) return;
    
    const container = this.canvas.parentElement;
    const rect = container.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    
    this.canvas.style.width = '100%';
    this.canvas.style.height = '100%';
    this.canvas.width = rect.width * dpr;
    this.canvas.height = rect.height * dpr;
    
    // Store the DPR for later use
    this.dpr = dpr;
    
    this.displayWidth = rect.width;
    this.displayHeight = rect.height;
  },

  startUpdates() {
    this.lastTime = 0;
    this.animate();
    
    // Add new data point every 3 seconds
    this.updateInterval = setInterval(() => {
      this.addNewDataPoint();
    }, 3000);
  },

  animate() {
    const currentTime = Date.now();
    
    if (currentTime - this.lastTime > 50) { // ~20fps for mini chart
      this.animateVolatility();
      this.drawChart();
      this.lastTime = currentTime;
    }
    
    this.animationFrame = requestAnimationFrame(() => this.animate());
  },

  animateVolatility() {
    // Add smooth micro-fluctuations to current volatility
    const time = Date.now() / 1000;
    const microVariation = 0.8; // ±0.8 point variation
    
    const baseValue = this.volatilityData[this.volatilityData.length - 1];
    const smoothVariation = Math.sin(time * 1.8) * microVariation + Math.cos(time * 0.9) * microVariation * 0.6;
    
    this.currentVolatility = Math.max(10, Math.min(80, baseValue + smoothVariation));
    
    // Update the last data point for smooth animation
    this.volatilityData[this.volatilityData.length - 1] = this.currentVolatility;
    
    // Update display value
    this.updateVolatilityDisplay();
  },

  addNewDataPoint() {
    // Remove oldest point
    this.volatilityData.shift();
    this.timeLabels.shift();
    
    // Generate new volatility value with trend
    const lastValue = this.volatilityData[this.volatilityData.length - 1];
    const trend = (Math.random() - 0.5) * 8; // ±4 point change
    const newValue = Math.max(10, Math.min(80, lastValue + trend)); // Keep between 10-80
    
    this.volatilityData.push(newValue);
    this.timeLabels.push(new Date());
    
    console.log('New volatility:', newValue.toFixed(1));
  },

  drawChart() {
    if (!this.ctx || !this.canvas) return;
    
    // Use actual canvas buffer dimensions
    const width = this.canvas.width / (this.dpr || 1);
    const height = this.canvas.height / (this.dpr || 1);
    
    // Reset and apply scale
    this.ctx.setTransform(1, 0, 0, 1, 0, 0);
    this.ctx.scale(this.dpr || 1, this.dpr || 1);
    
    // Clear entire canvas with dark background
    this.ctx.fillStyle = '#1F2937';
    this.ctx.fillRect(0, 0, width, height);
    
    // Draw the line chart
    this.drawVolatilityLine(width, height);
  },

  drawVolatilityLine(width, height) {
    if (this.volatilityData.length < 2) return;
    
    const padding = 2;
    const chartWidth = width - (padding * 2);
    const chartHeight = height - (padding * 2);
    const stepX = chartWidth / (this.volatilityData.length - 1);
    
    // Find min/max for scaling
    const minValue = Math.min(...this.volatilityData);
    const maxValue = Math.max(...this.volatilityData);
    const range = maxValue - minValue || 1;
    
    // Use green gradient like market cap
    const gradient = this.ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, '#10B981'); // Green
    gradient.addColorStop(1, '#059669'); // Darker green
    
    this.ctx.strokeStyle = gradient;
    this.ctx.lineWidth = 2;
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';
    this.ctx.beginPath();
    
    this.volatilityData.forEach((value, index) => {
      const x = padding + (stepX * index);
      const normalizedValue = (value - minValue) / range;
      const y = chartHeight - (normalizedValue * chartHeight) + padding;
      
      if (index === 0) {
        this.ctx.moveTo(x, y);
      } else {
        this.ctx.lineTo(x, y);
      }
    });
    
    this.ctx.stroke();
    
    // Draw filled area under line
    this.ctx.lineTo(width - padding, height - padding);
    this.ctx.lineTo(padding, height - padding);
    this.ctx.closePath();
    
    const areaGradient = this.ctx.createLinearGradient(0, 0, 0, height);
    areaGradient.addColorStop(0, 'rgba(16, 185, 129, 0.3)');
    areaGradient.addColorStop(1, 'rgba(16, 185, 129, 0.05)');
    
    this.ctx.fillStyle = areaGradient;
    this.ctx.fill();
  },

  // Removed getVolatilityColor - using consistent green

  // Removed drawCurrentValue - no text overlay on canvas

  updateVolatilityDisplay() {
    // Update external display elements if they exist
    const displayEl = document.querySelector('[data-volatility-value]');
    if (displayEl) {
      displayEl.textContent = Math.round(this.currentVolatility).toString();
    }
    
    const changeEl = document.querySelector('[data-volatility-change]');
    if (changeEl && this.volatilityData.length > 1) {
      const change = this.currentVolatility - this.volatilityData[this.volatilityData.length - 2];
      
      changeEl.textContent = (change > 0 ? '+' : '') + change.toFixed(2);
      changeEl.className = change > 0 ? 'text-red-400 text-xs' : 'text-green-400 text-xs';
    }
  }
};