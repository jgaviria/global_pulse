// Market Cap Mini Chart Component

export const MarketCapChart = {
  mounted() {
    console.log('MarketCapChart mounted');
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
    const canvas = this.el.querySelector('#market-cap-canvas');
    if (!canvas) {
      console.error('Market cap canvas not found');
      return;
    }

    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    
    // Store original canvas size
    this.setupCanvasSize();
    
    // Store these values to prevent resizing
    this.lockedWidth = this.displayWidth;
    this.lockedHeight = this.displayHeight;
    
    // Initialize market cap data (in trillions)
    this.dataPoints = 30;
    this.marketCapData = [];
    this.timeLabels = [];
    
    // Starting market cap around $45T
    const baseMarketCap = 45.2;
    const now = Date.now();
    
    for (let i = this.dataPoints - 1; i >= 0; i--) {
      const variation = (Math.random() - 0.5) * 2; // ±1T variation
      this.marketCapData.push(baseMarketCap + variation);
      this.timeLabels.push(new Date(now - i * 5000)); // Every 5 seconds
    }
    
    this.currentMarketCap = this.marketCapData[this.marketCapData.length - 1];
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
      this.animateMarketCap();
      this.drawChart();
      this.lastTime = currentTime;
    }
    
    this.animationFrame = requestAnimationFrame(() => this.animate());
  },

  animateMarketCap() {
    // Add smooth micro-fluctuations to current market cap
    const time = Date.now() / 1000;
    const microVariation = 0.1; // ±100B variation
    
    const baseValue = this.marketCapData[this.marketCapData.length - 1];
    const smoothVariation = Math.sin(time * 1.5) * microVariation + Math.cos(time * 0.8) * microVariation * 0.5;
    
    this.currentMarketCap = baseValue + smoothVariation;
    
    // Update the last data point for smooth animation
    this.marketCapData[this.marketCapData.length - 1] = this.currentMarketCap;
    
    // Update display value
    this.updateMarketCapDisplay();
  },

  addNewDataPoint() {
    // Remove oldest point
    this.marketCapData.shift();
    this.timeLabels.shift();
    
    // Generate new market cap value with trend
    const lastValue = this.marketCapData[this.marketCapData.length - 1];
    const trend = (Math.random() - 0.5) * 1.5; // ±750B change
    const newValue = Math.max(40, Math.min(50, lastValue + trend)); // Keep between 40T-50T
    
    this.marketCapData.push(newValue);
    this.timeLabels.push(new Date());
    
    console.log('New market cap:', newValue.toFixed(2) + 'T');
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
    this.drawMarketCapLine(width, height);
  },

  drawMarketCapLine(width, height) {
    if (this.marketCapData.length < 2) return;
    
    const padding = 2;
    const chartWidth = width - (padding * 2);
    const chartHeight = height - (padding * 2);
    const stepX = chartWidth / (this.marketCapData.length - 1);
    
    // Find min/max for scaling
    const minValue = Math.min(...this.marketCapData);
    const maxValue = Math.max(...this.marketCapData);
    const range = maxValue - minValue || 1;
    
    // Draw gradient line
    const gradient = this.ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, '#10B981'); // Green
    gradient.addColorStop(1, '#059669'); // Darker green
    
    this.ctx.strokeStyle = gradient;
    this.ctx.lineWidth = 2;
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';
    this.ctx.beginPath();
    
    this.marketCapData.forEach((value, index) => {
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

  // Removed drawCurrentValue - no text overlay on canvas

  updateMarketCapDisplay() {
    // Update external display elements if they exist
    const displayEl = document.querySelector('[data-market-cap-value]');
    if (displayEl) {
      displayEl.textContent = '$' + this.currentMarketCap.toFixed(2) + 'T';
    }
    
    const changeEl = document.querySelector('[data-market-cap-change]');
    if (changeEl && this.marketCapData.length > 1) {
      const change = this.currentMarketCap - this.marketCapData[this.marketCapData.length - 2];
      const changePercent = (change / this.marketCapData[this.marketCapData.length - 2]) * 100;
      
      changeEl.textContent = (change > 0 ? '+' : '') + change.toFixed(3) + 'T (' + 
                           (changePercent > 0 ? '+' : '') + changePercent.toFixed(2) + '%)';
      changeEl.className = change > 0 ? 'text-green-400 text-sm' : 'text-red-400 text-sm';
    }
  }
};