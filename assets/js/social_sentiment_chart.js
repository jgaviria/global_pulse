// Social Sentiment Chart Component

export const SocialSentimentChart = {
  mounted() {
    console.log('SocialSentimentChart mounted');
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
    const canvas = this.el.querySelector('#social-sentiment-canvas');
    if (!canvas) {
      console.error('Social sentiment canvas not found');
      return;
    }

    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    
    // Setup canvas size ONCE and lock it
    this.setupCanvasSize();
    
    // Lock the dimensions to prevent changes
    this.lockedWidth = this.displayWidth;
    this.lockedHeight = this.displayHeight;
    this.lockedCanvasWidth = this.canvas.width;
    this.lockedCanvasHeight = this.canvas.height;
    
    // Initialize data
    this.dataPoints = 20;
    this.sentimentData = [];
    this.labels = [];

    // Generate initial data
    const now = Date.now();
    for (let i = this.dataPoints - 1; i >= 0; i--) {
      this.sentimentData.push(this.randomValue(0.05));
      this.labels.push(new Date(now - i * 2000).toLocaleTimeString());
    }

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

  randomValue(base) {
    const variation = (Math.random() - 0.5) * 0.6;
    const trend = Math.sin(Date.now() / 20000) * 0.08;
    return base + variation + trend;
  },

  startUpdates() {
    this.animationFrame = null;
    this.lastTime = 0;
    
    this.targetValue = this.sentimentData[this.sentimentData.length - 1];
    
    // Start smooth animation loop
    this.animate();
    
    // Add new data points every 3 seconds
    this.updateInterval = setInterval(() => {
      this.addNewDataPoint();
    }, 3000);
  },

  animate() {
    const currentTime = Date.now();
    
    if (currentTime - this.lastTime > 16) { // ~60fps
      this.animateValues();
      this.drawChart();
      this.lastTime = currentTime;
    }
    
    this.animationFrame = requestAnimationFrame(() => this.animate());
  },

  animateValues() {
    const time = Date.now() / 1000;
    const microVariation = 0.02;
    
    const baseValue = this.targetValue;
    const variation = Math.cos(time * 2.1) * microVariation + Math.sin(time * 1.2) * microVariation * 0.7;
    
    this.sentimentData[this.sentimentData.length - 1] = baseValue + variation;
    
    // Update display value
    this.updateDisplayValue(this.sentimentData[this.sentimentData.length - 1]);
  },

  addNewDataPoint() {
    this.sentimentData.shift();
    this.labels.shift();

    this.targetValue = this.randomValue(0.05);

    this.sentimentData.push(this.targetValue);
    this.labels.push(new Date().toLocaleTimeString());
  },

  drawChart() {
    if (!this.ctx || !this.canvas) return;
    
    // CRITICAL: Always use locked dimensions, never recalculate
    const width = this.lockedWidth;
    const height = this.lockedHeight;
    
    // Ensure canvas buffer size hasn't changed
    if (this.canvas.width !== this.lockedCanvasWidth || this.canvas.height !== this.lockedCanvasHeight) {
      this.canvas.width = this.lockedCanvasWidth;
      this.canvas.height = this.lockedCanvasHeight;
    }
    
    // Clear and reset context
    this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    
    // Apply scale fresh each time
    this.ctx.setTransform(this.dpr || 1, 0, 0, this.dpr || 1, 0, 0);

    // Clear with background
    this.ctx.fillStyle = '#111827';
    this.ctx.fillRect(0, 0, width, height);

    // Draw grid
    this.drawGrid(width, height);
    
    // Draw line with green color matching financial dashboards
    this.drawLine(this.sentimentData, width, height);
  },

  drawGrid(width, height) {
    this.ctx.strokeStyle = 'rgba(75, 85, 99, 0.3)';
    this.ctx.lineWidth = 1 / (this.dpr || 1);

    // Horizontal lines
    for (let i = 0; i <= 4; i++) {
      const y = (height / 4) * i;
      this.ctx.beginPath();
      this.ctx.moveTo(50, y);
      this.ctx.lineTo(width - 20, y);
      this.ctx.stroke();
    }

    // Y-axis labels
    this.ctx.fillStyle = '#9CA3AF';
    this.ctx.font = '12px sans-serif';
    this.ctx.textAlign = 'right';
    
    for (let i = 0; i <= 4; i++) {
      const value = (0.5 - (i * 0.25)).toFixed(2);
      const y = (height / 4) * i + 4;
      this.ctx.fillText(value, 45, y);
    }
  },

  drawLine(data, width, height) {
    if (data.length < 2) return;

    const padding = 70;
    const chartWidth = width - padding;
    const chartHeight = height - 20;
    const stepX = chartWidth / (data.length - 1);

    // Draw gradient line with green like financial dashboards
    const gradient = this.ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, '#10B981'); // Green
    gradient.addColorStop(1, '#059669'); // Darker green

    this.ctx.strokeStyle = gradient;
    this.ctx.lineWidth = 2 / (this.dpr || 1);
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';
    this.ctx.beginPath();

    data.forEach((value, index) => {
      const x = 50 + (stepX * index);
      const normalizedValue = (value + 0.5) / 1.0;
      const y = chartHeight - (normalizedValue * chartHeight) + 10;
      
      if (index === 0) {
        this.ctx.moveTo(x, y);
      } else {
        this.ctx.lineTo(x, y);
      }
    });

    this.ctx.stroke();

    // Draw filled area
    this.ctx.lineTo(width - 20, chartHeight + 10);
    this.ctx.lineTo(50, chartHeight + 10);
    this.ctx.closePath();

    const areaGradient = this.ctx.createLinearGradient(0, 0, 0, height);
    areaGradient.addColorStop(0, 'rgba(16, 185, 129, 0.3)');
    areaGradient.addColorStop(1, 'rgba(16, 185, 129, 0.05)');

    this.ctx.fillStyle = areaGradient;
    this.ctx.fill();
  },

  updateDisplayValue(value) {
    const el = document.querySelector('[data-social-sentiment-value]');
    if (el) {
      el.textContent = value.toFixed(3);
      el.className = `text-2xl font-bold ${this.getValueColor(value)}`;
    }

    // Update progress bar
    const bar = document.querySelector('[data-social-sentiment-bar]');
    if (bar) {
      const percentage = Math.min(Math.abs(value * 200), 100);
      const color = value >= 0 ? 'bg-green-500' : 'bg-red-500';
      
      bar.style.width = `${percentage}%`;
      bar.className = `h-2 rounded-full transition-all duration-300 ${color}`;
    }
  },

  getValueColor(value) {
    if (value > 0.1) return 'text-green-400';
    if (value < -0.1) return 'text-red-400';
    return 'text-white';
  }
};