import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
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