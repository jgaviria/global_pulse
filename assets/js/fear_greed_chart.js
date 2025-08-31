// Fear & Greed Index Chart Component

export const FearGreedChart = {
  mounted() {
    console.log('FearGreedChart mounted');
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
    const canvas = this.el.querySelector('#fear-greed-canvas');
    if (!canvas) {
      console.error('Fear & Greed canvas not found');
      return;
    }

    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    
    // Store original canvas size
    this.setupCanvasSize();
    
    // Store these values to prevent resizing
    this.lockedWidth = this.displayWidth;
    this.lockedHeight = this.displayHeight;
    
    // Initialize fear & greed data (0-100 scale)
    this.dataPoints = 30;
    this.fearGreedData = [];
    this.timeLabels = [];
    
    // Starting fear & greed around 45 (neutral)
    const baseFearGreed = 45;
    const now = Date.now();
    
    for (let i = this.dataPoints - 1; i >= 0; i--) {
      const variation = (Math.random() - 0.5) * 20; // ±10 point variation
      this.fearGreedData.push(Math.max(0, Math.min(100, baseFearGreed + variation)));
      this.timeLabels.push(new Date(now - i * 5000)); // Every 5 seconds
    }
    
    this.currentFearGreed = this.fearGreedData[this.fearGreedData.length - 1];
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
      this.animateFearGreed();
      this.drawChart();
      this.lastTime = currentTime;
    }
    
    this.animationFrame = requestAnimationFrame(() => this.animate());
  },

  animateFearGreed() {
    // Add smooth micro-fluctuations to current fear & greed
    const time = Date.now() / 1000;
    const microVariation = 1.5; // ±1.5 point variation
    
    const baseValue = this.fearGreedData[this.fearGreedData.length - 1];
    const smoothVariation = Math.sin(time * 1.2) * microVariation + Math.cos(time * 0.6) * microVariation * 0.4;
    
    this.currentFearGreed = Math.max(0, Math.min(100, baseValue + smoothVariation));
    
    // Update the last data point for smooth animation
    this.fearGreedData[this.fearGreedData.length - 1] = this.currentFearGreed;
    
    // Update display value
    this.updateFearGreedDisplay();
  },

  addNewDataPoint() {
    // Remove oldest point
    this.fearGreedData.shift();
    this.timeLabels.shift();
    
    // Generate new fear & greed value with trend
    const lastValue = this.fearGreedData[this.fearGreedData.length - 1];
    const trend = (Math.random() - 0.5) * 15; // ±7.5 point change
    const newValue = Math.max(0, Math.min(100, lastValue + trend)); // Keep between 0-100
    
    this.fearGreedData.push(newValue);
    this.timeLabels.push(new Date());
    
    console.log('New fear & greed:', newValue.toFixed(0));
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
    this.drawFearGreedLine(width, height);
  },

  drawFearGreedLine(width, height) {
    if (this.fearGreedData.length < 2) return;
    
    const padding = 2;
    const chartWidth = width - (padding * 2);
    const chartHeight = height - (padding * 2);
    const stepX = chartWidth / (this.fearGreedData.length - 1);
    
    // Find min/max for scaling
    const minValue = Math.min(...this.fearGreedData);
    const maxValue = Math.max(...this.fearGreedData);
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
    
    this.fearGreedData.forEach((value, index) => {
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

  // Removed getFearGreedColor - using consistent green

  // Removed drawCurrentValue - no text overlay on canvas

  updateFearGreedDisplay() {
    // Update external display elements if they exist
    const displayEl = document.querySelector('[data-fear-greed-value]');
    if (displayEl) {
      displayEl.textContent = Math.round(this.currentFearGreed).toString();
    }
    
    const changeEl = document.querySelector('[data-fear-greed-change]');
    if (changeEl && this.fearGreedData.length > 1) {
      const change = this.currentFearGreed - this.fearGreedData[this.fearGreedData.length - 2];
      
      changeEl.textContent = (change > 0 ? '+' : '') + change.toFixed(1);
      changeEl.className = change > 0 ? 'text-green-400 text-xs' : 'text-red-400 text-xs';
    }
  }
};