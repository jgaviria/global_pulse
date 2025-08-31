// Live Sentiment Chart with real-time fluctuations

export const SentimentChart = {
  mounted() {
    console.log('SentimentChart mounted');
    // Wait a bit for the DOM to be ready
    setTimeout(() => {
      this.initializeChart();
      this.startRealTimeUpdates();
    }, 100);
  },

  updated() {
    this.updateChart();
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
    }
  },

  initializeChart() {
    const canvas = this.el.querySelector('#sentiment-chart-canvas');
    console.log('Canvas found:', !!canvas);
    if (!canvas) {
      console.error('Canvas not found!');
      return;
    }

    // Initialize data points with small fluctuating values
    this.sentimentData = {
      labels: [],
      overall: [],
      news: [],
      social: []
    };

    // Generate initial 20 data points
    const now = new Date();
    for (let i = 19; i >= 0; i--) {
      const time = new Date(now - i * 3000); // Every 3 seconds
      this.sentimentData.labels.push(time.toLocaleTimeString());
      this.sentimentData.overall.push(this.generateFluctuatingValue(0.1));
      this.sentimentData.news.push(this.generateFluctuatingValue(0.15));
      this.sentimentData.social.push(this.generateFluctuatingValue(0.05));
    }

    // Try Chart.js first, fallback to canvas if not available
    console.log('Chart.js available:', typeof Chart !== 'undefined');
    if (typeof Chart !== 'undefined') {
      this.initChartJS(canvas);
    } else {
      console.log('Using canvas fallback');
      this.initCanvasChart(canvas);
    }
  },

  initChartJS(ctx) {
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: this.sentimentData.labels,
        datasets: [{
          label: 'Overall Sentiment',
          data: this.sentimentData.overall,
          borderColor: 'rgb(59, 130, 246)',
          backgroundColor: 'rgba(59, 130, 246, 0.1)',
          fill: false,
          tension: 0.4,
          pointRadius: 2,
          pointHoverRadius: 4,
          borderWidth: 2
        }, {
          label: 'News Sentiment',
          data: this.sentimentData.news,
          borderColor: 'rgb(16, 185, 129)',
          backgroundColor: 'rgba(16, 185, 129, 0.1)',
          fill: false,
          tension: 0.4,
          pointRadius: 2,
          pointHoverRadius: 4,
          borderWidth: 2
        }, {
          label: 'Social Sentiment',
          data: this.sentimentData.social,
          borderColor: 'rgb(245, 158, 11)',
          backgroundColor: 'rgba(245, 158, 11, 0.1)',
          fill: false,
          tension: 0.4,
          pointRadius: 2,
          pointHoverRadius: 4,
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: {
          duration: 300,
          easing: 'easeInOutQuart'
        },
        interaction: {
          intersect: false,
          mode: 'index'
        },
        plugins: {
          legend: {
            labels: { 
              color: 'rgb(156, 163, 175)',
              usePointStyle: true,
              font: { size: 11 }
            }
          },
          tooltip: {
            backgroundColor: 'rgba(31, 41, 55, 0.9)',
            titleColor: 'rgb(243, 244, 246)',
            bodyColor: 'rgb(209, 213, 219)',
            borderColor: 'rgb(75, 85, 99)',
            borderWidth: 1,
            displayColors: true,
            callbacks: {
              label: function(context) {
                return `${context.dataset.label}: ${context.parsed.y.toFixed(3)}`;
              }
            }
          }
        },
        scales: {
          x: { 
            display: false, // Hide x-axis for cleaner look
            grid: { display: false }
          },
          y: { 
            min: -0.5,
            max: 0.5,
            ticks: { 
              color: 'rgb(156, 163, 175)',
              font: { size: 10 },
              callback: function(value) {
                return value.toFixed(2);
              }
            },
            grid: {
              color: 'rgba(75, 85, 99, 0.3)',
              drawBorder: false
            }
          }
        },
        elements: {
          line: {
            borderCapStyle: 'round'
          }
        }
      }
    });
  },

  initCanvasChart(canvas) {
    // Fallback to pure canvas implementation
    console.log('Initializing canvas chart');
    const rect = canvas.getBoundingClientRect();
    console.log('Canvas rect:', rect);
    
    canvas.width = rect.width * window.devicePixelRatio || 800;
    canvas.height = rect.height * window.devicePixelRatio || 256;
    canvas.style.width = (rect.width || 400) + 'px';
    canvas.style.height = (rect.height || 128) + 'px';
    
    this.ctx = canvas.getContext('2d');
    this.ctx.scale(window.devicePixelRatio || 1, window.devicePixelRatio || 1);
    this.canvasWidth = rect.width || 400;
    this.canvasHeight = rect.height || 128;
    
    console.log('Canvas dimensions:', this.canvasWidth, 'x', this.canvasHeight);
    
    // Draw test rectangle to verify canvas is working
    this.ctx.fillStyle = 'red';
    this.ctx.fillRect(10, 10, 50, 30);
    
    this.drawCanvasChart();
  },

  drawCanvasChart() {
    if (!this.ctx) return;
    
    const width = this.canvasWidth || 400;
    const height = this.canvasHeight || 128;
    
    // Clear canvas
    this.ctx.clearRect(0, 0, width, height);
    
    // Draw grid
    this.ctx.strokeStyle = 'rgba(75, 85, 99, 0.3)';
    this.ctx.lineWidth = 1;
    
    // Horizontal grid lines
    for (let i = 0; i <= 4; i++) {
      const y = (height / 4) * i;
      this.ctx.beginPath();
      this.ctx.moveTo(40, y);
      this.ctx.lineTo(width - 20, y);
      this.ctx.stroke();
    }
    
    // Draw data lines
    this.drawLine(this.sentimentData.overall, '#3B82F6', width, height);
    this.drawLine(this.sentimentData.news, '#10B981', width, height);
    this.drawLine(this.sentimentData.social, '#F59E0B', width, height);
    
    // Draw legend
    this.drawLegend(width, height);
  },

  drawLine(data, color, width, height) {
    if (data.length < 2) return;
    
    const padding = 50;
    const chartWidth = width - padding;
    const chartHeight = height - 40;
    const stepX = chartWidth / (data.length - 1);
    
    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = 2;
    this.ctx.beginPath();
    
    data.forEach((value, index) => {
      const x = 40 + (stepX * index);
      const y = chartHeight - ((value + 0.5) * chartHeight);
      
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
    
    this.ctx.fillStyle = 'rgb(156, 163, 175)';
    this.ctx.font = '12px sans-serif';
    
    legends.forEach((legend, index) => {
      const x = 50 + (index * 80);
      const y = height - 10;
      
      // Draw color indicator
      this.ctx.fillStyle = legend.color;
      this.ctx.fillRect(x, y - 8, 12, 3);
      
      // Draw label
      this.ctx.fillStyle = 'rgb(156, 163, 175)';
      this.ctx.fillText(legend.label, x + 18, y - 2);
    });
  },

  startRealTimeUpdates() {
    // Update chart every 2 seconds with new fluctuating values
    this.updateInterval = setInterval(() => {
      this.addNewDataPoint();
    }, 2000);
  },

  addNewDataPoint() {
    if (!this.chart && !this.ctx) return;

    const now = new Date();
    const timeLabel = now.toLocaleTimeString();

    // Generate new fluctuating values
    const newOverall = this.generateFluctuatingValue(0.1);
    const newNews = this.generateFluctuatingValue(0.15);
    const newSocial = this.generateFluctuatingValue(0.05);

    // Add new data point
    this.sentimentData.labels.push(timeLabel);
    this.sentimentData.overall.push(newOverall);
    this.sentimentData.news.push(newNews);
    this.sentimentData.social.push(newSocial);

    // Keep only last 20 points for smooth scrolling effect
    if (this.sentimentData.labels.length > 20) {
      this.sentimentData.labels.shift();
      this.sentimentData.overall.shift();
      this.sentimentData.news.shift();
      this.sentimentData.social.shift();
    }

    // Update chart - Chart.js or Canvas
    if (this.chart) {
      this.chart.data.labels = this.sentimentData.labels;
      this.chart.data.datasets[0].data = this.sentimentData.overall;
      this.chart.data.datasets[1].data = this.sentimentData.news;
      this.chart.data.datasets[2].data = this.sentimentData.social;
      this.chart.update('none'); // No animation for smooth real-time feel
    } else if (this.ctx) {
      this.drawCanvasChart();
    }

    // Update the sentiment display values
    this.updateSentimentDisplays(newOverall, newNews, newSocial);
  },

  generateFluctuatingValue(baseValue) {
    // Generate small fluctuating values around base value
    const variation = (Math.random() - 0.5) * 0.6; // Range of ±0.3
    const trendComponent = Math.sin(Date.now() / 30000) * 0.1; // Slow trend
    const volatility = (Math.random() - 0.5) * 0.2; // Random volatility
    
    return baseValue + variation + trendComponent + volatility;
  },

  updateChart() {
    // Called when LiveView updates - can sync with external data if needed
    if (this.chart && this.el.dataset.sentiment) {
      try {
        const sentimentData = JSON.parse(this.el.dataset.sentiment);
        // Use external data as base values for fluctuation
        this.baseValues = {
          overall: sentimentData.overall || 0.1,
          news: sentimentData.news || 0.15,
          social: sentimentData.social || 0.05
        };
      } catch (e) {
        // Continue with internal fluctuation if parsing fails
      }
    }
  },

  updateSentimentDisplays(overall, news, social) {
    // Update the sentiment value displays in the UI
    const overallEl = this.el.querySelector('[data-overall-sentiment]');
    const newsEl = this.el.querySelector('[data-news-sentiment]');
    const socialEl = this.el.querySelector('[data-social-sentiment]');

    if (overallEl) {
      overallEl.textContent = overall.toFixed(3);
      overallEl.className = `text-3xl font-bold ${this.getSentimentColor(overall)}`;
    }
    if (newsEl) {
      newsEl.textContent = news.toFixed(3);
      newsEl.className = `text-3xl font-bold ${this.getSentimentColor(news)}`;
    }
    if (socialEl) {
      socialEl.textContent = social.toFixed(3);
      socialEl.className = `text-3xl font-bold ${this.getSentimentColor(social)}`;
    }

    // Update progress bars
    this.updateProgressBar('[data-overall-bar]', overall);
    this.updateProgressBar('[data-news-bar]', news);
    this.updateProgressBar('[data-social-bar]', social);
  },

  getSentimentColor(value) {
    if (value > 0.1) return 'text-green-400';
    if (value < -0.1) return 'text-red-400';
    return 'text-white';
  },

  updateProgressBar(selector, value) {
    const bar = this.el.querySelector(selector);
    if (bar) {
      const percentage = Math.min(Math.abs(value * 200), 100); // Scale to 0-100%
      const color = value >= 0 ? 'bg-green-500' : 'bg-red-500';
      
      bar.style.width = `${percentage}%`;
      bar.className = `h-2 rounded-full transition-all duration-300 ${color}`;
    }
  }
};