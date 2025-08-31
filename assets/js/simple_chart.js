// Simple, reliable canvas chart implementation

export const SimpleChart = {
  mounted() {
    console.log('SimpleChart mounted - this should appear in console');
    
    if (this.initialized) {
      console.log('Already initialized, skipping');
      return;
    }
    
    // First, let's just make sure we can draw something basic
    const canvas = this.el.querySelector('#sentiment-chart-canvas');
    if (!canvas) {
      console.error('Canvas not found!');
      return;
    }
    
    console.log('Canvas found, testing basic drawing');
    const ctx = canvas.getContext('2d');
    
    // Set canvas size immediately
    const container = canvas.parentElement;
    console.log('Container dimensions:', container.offsetWidth, 'x', container.offsetHeight);
    
    canvas.width = container.offsetWidth || 400;
    canvas.height = container.offsetHeight || 200;
    
    // Draw a simple test pattern to verify canvas works
    ctx.fillStyle = '#1F2937'; // dark background
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    ctx.fillStyle = '#3B82F6'; // blue
    ctx.fillRect(20, 20, 100, 30);
    
    ctx.fillStyle = '#10B981'; // green  
    ctx.fillRect(20, 60, 150, 30);
    
    ctx.fillStyle = '#F59E0B'; // yellow
    ctx.fillRect(20, 100, 80, 30);
    
    ctx.fillStyle = '#FFFFFF';
    ctx.font = '16px sans-serif';
    ctx.fillText('Chart Loading...', 20, 160);
    
    console.log('Basic test pattern drawn');
    
    // Mark as initialized
    this.initialized = true;
    
    // Now try to initialize the full chart
    setTimeout(() => {
      this.initializeChart();
      this.startUpdates();
    }, 100);
  },

  updated() {
    // Completely ignore LiveView updates to prevent interference
    // Our animation is self-contained and doesn't need LiveView data
    return false; // Prevent any LiveView interference
  },

  destroyed() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
    }
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame);
    }
    if (this.observer) {
      this.observer.disconnect();
    }
  },

  initializeChart() {
    const canvas = this.el.querySelector('#sentiment-chart-canvas');
    if (!canvas) {
      console.error('Canvas not found');
      return;
    }

    this.canvas = canvas; // Store canvas reference
    this.ctx = canvas.getContext('2d');
    
    // Set fixed canvas size to prevent LiveView interference
    const container = canvas.parentElement;
    const rect = container.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    
    // Set display size
    canvas.style.width = '100%';
    canvas.style.height = '100%';
    
    // Set actual size in memory (scaled for retina)
    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;
    
    // Scale context to ensure correct drawing operations
    this.ctx.scale(dpr, dpr);
    
    // Store dimensions
    this.displayWidth = rect.width;
    this.displayHeight = rect.height;
    
    console.log('Canvas initialized:', this.displayWidth, 'x', this.displayHeight, 'DPR:', dpr);

    // Initialize data
    this.dataPoints = 20;
    this.overallData = [];
    this.newsData = [];
    this.socialData = [];
    this.labels = [];

    // Generate initial data
    const now = Date.now();
    for (let i = this.dataPoints - 1; i >= 0; i--) {
      this.overallData.push(this.randomValue(0.1));
      this.newsData.push(this.randomValue(0.15)); 
      this.socialData.push(this.randomValue(0.05));
      this.labels.push(new Date(now - i * 2000).toLocaleTimeString());
    }

    this.drawChart();
  },

  randomValue(base) {
    const variation = (Math.random() - 0.5) * 0.6;
    const trend = Math.sin(Date.now() / 30000) * 0.1;
    return base + variation + trend;
  },

  startUpdates() {
    // Smooth animation variables
    this.animationFrame = null;
    this.lastTime = 0;
    this.interpolationFactor = 0;
    
    // Target values for smooth interpolation
    this.targetOverall = this.overallData[this.overallData.length - 1];
    this.targetNews = this.newsData[this.newsData.length - 1];
    this.targetSocial = this.socialData[this.socialData.length - 1];
    
    // Lock canvas to prevent external modification
    this.lockCanvas();
    
    // Start smooth animation loop
    this.animate();
    
    // Add new data points every 3 seconds (but animate smoothly between)
    this.updateInterval = setInterval(() => {
      this.addNewDataPoint();
    }, 3000);
  },

  animate() {
    const currentTime = Date.now();
    
    if (currentTime - this.lastTime > 16) { // ~60fps
      // Check if canvas dimensions have changed (this would cause blurriness)
      if (this.canvas && (this.canvas.clientWidth !== this.displayWidth || this.canvas.clientHeight !== this.displayHeight)) {
        console.warn('Canvas size changed! Old:', this.displayWidth, 'x', this.displayHeight, 'New:', this.canvas.clientWidth, 'x', this.canvas.clientHeight);
        // Don't reinitialize, just log it
      }
      
      // Continuously fluctuate values with smooth animation
      this.animateValues();
      this.drawChart();
      this.lastTime = currentTime;
    }
    
    this.animationFrame = requestAnimationFrame(() => this.animate());
  },

  animateValues() {
    // Create smooth micro-fluctuations between data points
    const time = Date.now() / 1000;
    const microVariation = 0.02;
    
    // Add smooth sine wave variations to each line
    const overallBase = this.targetOverall;
    const newsBase = this.targetNews;
    const socialBase = this.targetSocial;
    
    // Different frequencies for each line to create natural movement
    const overallVariation = Math.sin(time * 2.3) * microVariation + Math.sin(time * 0.7) * microVariation * 0.5;
    const newsVariation = Math.sin(time * 1.8) * microVariation + Math.cos(time * 0.9) * microVariation * 0.3;
    const socialVariation = Math.cos(time * 2.1) * microVariation + Math.sin(time * 1.2) * microVariation * 0.7;
    
    // Update the last data point with smooth variations
    this.overallData[this.overallData.length - 1] = overallBase + overallVariation;
    this.newsData[this.newsData.length - 1] = newsBase + newsVariation;
    this.socialData[this.socialData.length - 1] = socialBase + socialVariation;
    
    // Update display values
    this.updateDisplayValues(
      this.overallData[this.overallData.length - 1],
      this.newsData[this.newsData.length - 1],
      this.socialData[this.socialData.length - 1]
    );
  },

  addNewDataPoint() {
    // Shift old data
    this.overallData.shift();
    this.newsData.shift();
    this.socialData.shift();
    this.labels.shift();

    // Generate new target values
    this.targetOverall = this.randomValue(0.1);
    this.targetNews = this.randomValue(0.15);
    this.targetSocial = this.randomValue(0.05);

    // Add new data points
    this.overallData.push(this.targetOverall);
    this.newsData.push(this.targetNews);
    this.socialData.push(this.targetSocial);
    this.labels.push(new Date().toLocaleTimeString());
  },

  drawChart() {
    if (!this.ctx || !this.canvas) return;

    // Check if canvas context was lost
    if (this.ctx.isContextLost && this.ctx.isContextLost()) {
      console.warn('Canvas context lost, reinitializing...');
      this.initializeChart();
      return;
    }

    const width = this.displayWidth;
    const height = this.displayHeight;

    // Clear canvas
    this.ctx.fillStyle = '#111827'; // gray-900
    this.ctx.fillRect(0, 0, width, height);

    // Draw grid
    this.drawGrid(width, height);
    
    // Draw lines
    this.drawLine(this.overallData, '#3B82F6', width, height); // blue
    this.drawLine(this.newsData, '#10B981', width, height);    // green
    this.drawLine(this.socialData, '#F59E0B', width, height);  // yellow

    // Draw legend
    this.drawLegend(width, height);
  },

  drawGrid(width, height) {
    this.ctx.strokeStyle = 'rgba(75, 85, 99, 0.3)';
    this.ctx.lineWidth = 1;

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

  drawLine(data, color, width, height) {
    if (data.length < 2) return;

    const padding = 70;
    const chartWidth = width - padding;
    const chartHeight = height - 20;
    const stepX = chartWidth / (data.length - 1);

    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = 3;
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';
    this.ctx.beginPath();

    data.forEach((value, index) => {
      const x = 50 + (stepX * index);
      // Map value from [-0.5, 0.5] to canvas height
      const normalizedValue = (value + 0.5) / 1.0; // Convert to 0-1
      const y = chartHeight - (normalizedValue * chartHeight) + 10;
      
      if (index === 0) {
        this.ctx.moveTo(x, y);
      } else {
        this.ctx.lineTo(x, y);
      }
    });

    this.ctx.stroke();
  },

  drawLegend(width, height) {
    const legends = [
      { color: '#3B82F6', label: 'Overall' },
      { color: '#10B981', label: 'News' },
      { color: '#F59E0B', label: 'Social' }
    ];

    this.ctx.font = '14px sans-serif';
    this.ctx.textAlign = 'left';

    legends.forEach((legend, index) => {
      const x = 70 + (index * 100);
      const y = height - 15;

      // Draw line indicator
      this.ctx.strokeStyle = legend.color;
      this.ctx.lineWidth = 3;
      this.ctx.beginPath();
      this.ctx.moveTo(x, y - 5);
      this.ctx.lineTo(x + 20, y - 5);
      this.ctx.stroke();

      // Draw label
      this.ctx.fillStyle = '#D1D5DB';
      this.ctx.fillText(legend.label, x + 25, y);
    });
  },

  updateDisplayValues(overall, news, social) {
    const overallEl = document.querySelector('[data-overall-sentiment]');
    const newsEl = document.querySelector('[data-news-sentiment]');
    const socialEl = document.querySelector('[data-social-sentiment]');

    if (overallEl) {
      overallEl.textContent = overall.toFixed(3);
      overallEl.className = `text-2xl font-bold ${this.getValueColor(overall)}`;
    }
    if (newsEl) {
      newsEl.textContent = news.toFixed(3);
      newsEl.className = `text-2xl font-bold ${this.getValueColor(news)}`;
    }
    if (socialEl) {
      socialEl.textContent = social.toFixed(3);
      socialEl.className = `text-2xl font-bold ${this.getValueColor(social)}`;
    }

    // Update progress bars
    this.updateProgressBar('[data-overall-bar]', overall);
    this.updateProgressBar('[data-news-bar]', news);
    this.updateProgressBar('[data-social-bar]', social);
  },

  getValueColor(value) {
    if (value > 0.1) return 'text-green-400';
    if (value < -0.1) return 'text-red-400';
    return 'text-white';
  },

  updateProgressBar(selector, value) {
    const bar = document.querySelector(selector);
    if (bar) {
      const percentage = Math.min(Math.abs(value * 200), 100);
      const color = value >= 0 ? 'bg-green-500' : 'bg-red-500';
      
      bar.style.width = `${percentage}%`;
      bar.className = `h-2 rounded-full transition-all duration-300 ${color}`;
    }
  },

  lockCanvas() {
    if (!this.canvas) return;
    
    // Create a MutationObserver to watch for any changes to the canvas
    this.observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === 'attributes' && mutation.attributeName === 'style') {
          // Canvas style was changed, restore it
          console.warn('Canvas style changed, restoring...');
          this.canvas.style.width = '100%';
          this.canvas.style.height = '100%';
        }
      });
    });
    
    // Start observing
    this.observer.observe(this.canvas, {
      attributes: true,
      attributeFilter: ['style', 'width', 'height']
    });
    
    // Also prevent resize observer interference
    Object.defineProperty(this.canvas, 'width', {
      writable: false,
      configurable: false
    });
    Object.defineProperty(this.canvas, 'height', {
      writable: false,
      configurable: false
    });
  },

  redrawChart() {
    if (this.ctx) {
      this.drawChart();
    }
  }
};