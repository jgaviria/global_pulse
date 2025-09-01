import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import ApexCharts from "apexcharts"
import {PoliticalLive} from "./political_live"
import {SentimentChart} from "./sentiment_chart"
import {SimpleChart} from "./simple_chart"
import {TestHook} from "./test_hook"
import {MarketCapChart} from "./market_cap_chart"
import {FearGreedChart} from "./fear_greed_chart"
import {VolatilityChart} from "./volatility_chart"
import {OverallSentimentChart} from "./overall_sentiment_chart"
import {NewsSentimentChart} from "./news_sentiment_chart"
import {SocialSentimentChart} from "./social_sentiment_chart"
import {MagnetosphereAnimation} from "./van_allen_animation"
import {ThreeJSMagnetosphere} from "./threejs_magnetosphere"
import {SolarWindAnimation} from "./solar_wind_animation"
import {KPIntensityBar} from "./kp_intensity_bar"
import {SolarWindIntensityBar} from "./solar_wind_intensity_bar"
import {EarthquakeGlobe} from "./earthquake_globe_globegl"

// Make Chart.js available globally if it exists
if (typeof Chart !== 'undefined') {
  window.Chart = Chart;
}

// Chart.js hooks for LiveView
let Hooks = {}

// Political Live Feed Hook
Hooks.PoliticalLive = PoliticalLive

// Live Sentiment Chart Hook
Hooks.SentimentChart = SentimentChart

// Simple Chart Hook (fallback)
Hooks.SimpleChart = SimpleChart

// Test Hook
Hooks.TestHook = TestHook

// Market Cap Chart Hook
Hooks.MarketCapChart = MarketCapChart

// Fear & Greed Chart Hook
Hooks.FearGreedChart = FearGreedChart

// Volatility Chart Hook
Hooks.VolatilityChart = VolatilityChart

// Individual Sentiment Chart Hooks
Hooks.OverallSentimentChart = OverallSentimentChart
Hooks.NewsSentimentChart = NewsSentimentChart
Hooks.SocialSentimentChart = SocialSentimentChart

// Advanced Magnetosphere Animation Hook
Hooks.MagnetosphereAnimation = MagnetosphereAnimation

// Three.js Magnetosphere Hook  
Hooks.ThreeJSMagnetosphere = ThreeJSMagnetosphere

// Solar Wind Stream Animation Hook
Hooks.SolarWindAnimation = SolarWindAnimation

// Intensity Bar Hooks
Hooks.KPIntensityBar = KPIntensityBar
Hooks.SolarWindIntensityBar = SolarWindIntensityBar

// Earthquake Globe Hook
Hooks.EarthquakeGlobe = EarthquakeGlobe

// Infinite Scroll Hook
Hooks.InfiniteScroll = {
  mounted() {
    this.observer = new IntersectionObserver(
      entries => {
        const target = entries[0]
        if (target.isIntersecting) {
          this.pushEvent("load_more_articles", {})
        }
      },
      {
        root: this.el,
        rootMargin: '100px',
        threshold: 0.1
      }
    )
    
    // Observe the load-more-trigger element when it exists
    this.observeLoadTrigger()
  },
  
  updated() {
    // Re-observe the trigger after DOM updates
    this.observeLoadTrigger()
  },
  
  destroyed() {
    if (this.observer) {
      this.observer.disconnect()
    }
  },
  
  observeLoadTrigger() {
    // Stop observing previous trigger
    if (this.currentTarget) {
      this.observer.unobserve(this.currentTarget)
    }
    
    // Find and observe new trigger
    const trigger = this.el.querySelector('#load-more-trigger')
    if (trigger) {
      this.observer.observe(trigger)
      this.currentTarget = trigger
    }
  }
}

// ApexCharts Gauge Hook
Hooks.GaugeChart = {
  mounted() {
    this.initChart()
  },
  
  updated() {
    // Handle real-time updates from LiveView
    this.handleUpdate()
  },
  
  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },
  
  initChart() {
    const category = this.el.dataset.category
    const value = parseFloat(this.el.dataset.value) || 0
    const baseline7d = parseFloat(this.el.dataset.baseline7d) || 0
    const baseline30d = parseFloat(this.el.dataset.baseline30d) || 0
    const minValue = parseFloat(this.el.dataset.minValue) || 0
    const maxValue = parseFloat(this.el.dataset.maxValue) || 100
    const colors = JSON.parse(this.el.dataset.colors || '{}')
    const confidence = parseFloat(this.el.dataset.confidence) || 0.5
    
    // Calculate gauge range and colors based on category
    const gaugeColors = this.getGaugeColors(category, colors)
    const {plotBands, valueDisplay} = this.getGaugeConfig(category, value, baseline7d, baseline30d, minValue, maxValue)
    
    const options = {
      series: [Math.round((value - minValue) / (maxValue - minValue) * 100)],
      chart: {
        height: 250,
        type: 'radialBar',
        background: 'transparent',
        animations: {
          enabled: true,
          easing: 'easeinout',
          speed: 800,
          animateGradually: {
            enabled: true,
            delay: 150
          },
          dynamicAnimation: {
            enabled: true,
            speed: 350
          }
        }
      },
      plotOptions: {
        radialBar: {
          offsetY: 0,
          startAngle: -135,
          endAngle: 135,
          hollow: {
            margin: 5,
            size: '65%',
            background: 'transparent'
          },
          dataLabels: {
            name: {
              show: true,
              fontSize: '14px',
              color: '#9CA3AF',
              offsetY: -10
            },
            value: {
              show: true,
              fontSize: '20px',
              fontWeight: 'bold',
              color: colors.text || '#F3F4F6',
              offsetY: 5,
              formatter: function(val) {
                return valueDisplay
              }
            }
          },
          track: {
            background: colors.background || '#374151',
            strokeWidth: '100%',
            margin: 5,
            opacity: 0.4
          }
        }
      },
      fill: {
        type: 'gradient',
        gradient: {
          shade: 'dark',
          type: 'horizontal',
          shadeIntensity: 0.5,
          gradientToColors: [gaugeColors.end],
          inverseColors: true,
          opacityFrom: 1,
          opacityTo: 1,
          stops: [0, 100]
        }
      },
      colors: [gaugeColors.start],
      stroke: {
        dashArray: 4,
        lineCap: 'round'
      },
      labels: [category.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())],
      responsive: [{
        breakpoint: 480,
        options: {
          chart: {
            height: 200
          }
        }
      }]
    }
    
    this.chart = new ApexCharts(this.el, options)
    this.chart.render()
    
    // Add baseline indicators
    this.addBaselineIndicators(baseline7d, baseline30d, minValue, maxValue, colors)
  },
  
  handleUpdate() {
    // This will be called when the component receives update_gauge event
    const value = parseFloat(this.el.dataset.value) || 0
    const minValue = parseFloat(this.el.dataset.minValue) || 0
    const maxValue = parseFloat(this.el.dataset.maxValue) || 100
    const category = this.el.dataset.category
    
    const percentage = Math.round((value - minValue) / (maxValue - minValue) * 100)
    const valueDisplay = this.formatDisplayValue(value, category)
    
    if (this.chart) {
      this.chart.updateSeries([percentage])
      // Update the value display
      this.chart.updateOptions({
        plotOptions: {
          radialBar: {
            dataLabels: {
              value: {
                formatter: function(val) {
                  return valueDisplay
                }
              }
            }
          }
        }
      })
    }
  },
  
  getGaugeColors(category, colors) {
    switch(category) {
      case 'sentiment':
        return {
          start: '#EF4444', // Red
          end: '#10B981'    // Green
        }
      case 'financial':
        return {
          start: '#8B5CF6', // Purple
          end: '#3B82F6'    // Blue
        }
      case 'natural_events':
        return {
          start: '#10B981', // Green (low severity is good)
          end: '#EF4444'    // Red (high severity is bad)
        }
      case 'social_trends':
        return {
          start: '#6B7280', // Gray
          end: '#EC4899'    // Pink
        }
      default:
        return {
          start: colors.primary || '#3B82F6',
          end: colors.accent || '#10B981'
        }
    }
  },
  
  getGaugeConfig(category, value, baseline7d, baseline30d, minValue, maxValue) {
    let valueDisplay, plotBands
    
    switch(category) {
      case 'sentiment':
        if (value > 0.7) {
          valueDisplay = `${Math.round(value * 100)}% Positive`
        } else if (value > 0.3) {
          valueDisplay = `${Math.round(value * 100)}% Neutral`
        } else {
          valueDisplay = `${Math.round(value * 100)}% Negative`
        }
        break
      default:
        valueDisplay = `${value.toFixed(1)}`
    }
    
    plotBands = [
      {
        from: baseline7d,
        to: baseline30d,
        color: 'rgba(59, 130, 246, 0.2)',
        label: '7-30d Range'
      }
    ]
    
    return { plotBands, valueDisplay }
  },
  
  formatDisplayValue(value, category) {
    switch(category) {
      case 'sentiment':
        if (value > 0.7) {
          return `${Math.round(value * 100)}% Positive`
        } else if (value > 0.3) {
          return `${Math.round(value * 100)}% Neutral`
        } else {
          return `${Math.round(value * 100)}% Negative`
        }
      default:
        return `${value.toFixed(1)}`
    }
  },
  
  addBaselineIndicators(baseline7d, baseline30d, minValue, maxValue, colors) {
    // Add subtle baseline indicator lines using CSS
    const baseline7dPercent = (baseline7d - minValue) / (maxValue - minValue) * 100
    const baseline30dPercent = (baseline30d - minValue) / (maxValue - minValue) * 100
    
    // Create baseline indicator elements
    const indicator = document.createElement('div')
    indicator.innerHTML = `
      <div class="absolute inset-0 flex items-center justify-center pointer-events-none">
        <div class="text-xs text-gray-400 mt-16">
          <div class="flex space-x-4">
            <span class="bg-blue-600 w-2 h-1 inline-block rounded mr-1"></span>7d: ${baseline7d.toFixed(1)}
            <span class="bg-purple-600 w-2 h-1 inline-block rounded mr-1"></span>30d: ${baseline30d.toFixed(1)}
          </div>
        </div>
      </div>
    `
    indicator.className = 'relative'
    this.el.appendChild(indicator)
  }
}

Hooks.CryptoChart = {
  mounted() {
    const ctx = this.el.querySelector('#crypto-canvas')
    const data = JSON.parse(this.el.dataset.prices)
    
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: data.map(d => d.name),
        datasets: [{
          label: 'Price (USD)',
          data: data.map(d => d.price),
          borderColor: 'rgb(59, 130, 246)',
          backgroundColor: 'rgba(59, 130, 246, 0.1)',
          tension: 0.1
        }, {
          label: '24h Change %',
          data: data.map(d => d.change_percent),
          borderColor: 'rgb(16, 185, 129)',
          backgroundColor: 'rgba(16, 185, 129, 0.1)',
          yAxisID: 'y1',
          tension: 0.1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        layout: {
          padding: 0
        },
        plugins: {
          legend: {
            labels: { color: 'rgb(156, 163, 175)' }
          }
        },
        scales: {
          x: { ticks: { color: 'rgb(156, 163, 175)' }},
          y: { 
            ticks: { color: 'rgb(156, 163, 175)' },
            beginAtZero: false
          },
          y1: {
            type: 'linear',
            display: true,
            position: 'right',
            ticks: { color: 'rgb(156, 163, 175)' },
            grid: { drawOnChartArea: false }
          }
        }
      }
    })
  },
  
  updated() {
    if (this.chart) {
      const data = JSON.parse(this.el.dataset.prices)
      this.chart.data.labels = data.map(d => d.name)
      this.chart.data.datasets[0].data = data.map(d => d.price)
      this.chart.data.datasets[1].data = data.map(d => d.change_percent)
      this.chart.update('none')
    }
  },
  
  destroyed() {
    if (this.chart) this.chart.destroy()
  }
}

Hooks.StocksChart = {
  mounted() {
    const ctx = this.el.querySelector('#stocks-canvas')
    const data = JSON.parse(this.el.dataset.stocks)
    
    this.chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: data.map(d => d.name),
        datasets: [{
          label: 'Price',
          data: data.map(d => d.price),
          backgroundColor: data.map(d => 
            d.change >= 0 ? 'rgba(16, 185, 129, 0.6)' : 'rgba(239, 68, 68, 0.6)'
          ),
          borderColor: data.map(d => 
            d.change >= 0 ? 'rgb(16, 185, 129)' : 'rgb(239, 68, 68)'
          ),
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        layout: {
          padding: 0
        },
        plugins: {
          legend: { display: false }
        },
        scales: {
          x: { ticks: { color: 'rgb(156, 163, 175)' }},
          y: { ticks: { color: 'rgb(156, 163, 175)' }}
        }
      }
    })
  },
  
  updated() {
    if (this.chart) {
      const data = JSON.parse(this.el.dataset.stocks)
      this.chart.data.labels = data.map(d => d.name)
      this.chart.data.datasets[0].data = data.map(d => d.price)
      this.chart.update('none')
    }
  },
  
  destroyed() {
    if (this.chart) this.chart.destroy()
  }
}

Hooks.VolumeChart = {
  mounted() {
    const ctx = this.el.querySelector('#volume-canvas')
    const volumeData = JSON.parse(this.el.dataset.volume)
    
    this.chart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: volumeData.labels || [],
        datasets: [{
          data: volumeData.data || [],
          backgroundColor: [
            'rgba(59, 130, 246, 0.8)',
            'rgba(16, 185, 129, 0.8)',
            'rgba(245, 158, 11, 0.8)',
            'rgba(239, 68, 68, 0.8)',
            'rgba(139, 92, 246, 0.8)'
          ]
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        layout: {
          padding: 0
        },
        plugins: {
          legend: {
            position: 'bottom',
            labels: { color: 'rgb(156, 163, 175)' }
          }
        }
      }
    })
  },
  
  updated() {
    if (this.chart) {
      const volumeData = JSON.parse(this.el.dataset.volume)
      this.chart.data.labels = volumeData.labels || []
      this.chart.data.datasets[0].data = volumeData.data || []
      this.chart.update('none')
    }
  },
  
  destroyed() {
    if (this.chart) this.chart.destroy()
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket