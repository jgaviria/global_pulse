# 🌍 Global Pulse

A real-time monitoring system that tracks financial markets, political climate, and natural events to detect potential inflection points using machine learning algorithms built with Elixir and Phoenix LiveView.

## 🚀 Features

### 📈 Financial Monitoring
- **Real-time market data**: Stocks, cryptocurrencies, forex, and commodities
- **Crypto WebSocket streams**: Live price feeds from Binance
- **Market sentiment analysis**: Fear & Greed Index, volatility tracking
- **Anomaly detection**: Price spikes, volume anomalies, correlation breaks

### 🗳️ Political Climate Analysis
- **News sentiment analysis**: Real-time processing of political news
- **Social media trends**: Twitter hashtags and Reddit discussions
- **Breaking news detection**: High-impact political events
- **Sentiment tracking**: Regional and categorical sentiment analysis

### 🌍 Natural Events Monitoring
- **Earthquake tracking**: USGS real-time earthquake feeds (M4.5+)
- **Weather events**: Severe weather alerts and hurricane tracking
- **Space weather**: Solar flares, geomagnetic storms, aurora forecasts
- **Wildfire tracking**: Active fire perimeters and containment status

### 🎯 Machine Learning Pipeline
- **Inflection point detection**: Pattern recognition across all data streams
- **Cross-domain correlation analysis**: Financial-political-natural event relationships
- **Anomaly scoring**: Multi-factor risk assessment
- **Predictive modeling**: Early warning system for market/social disruptions

## 🏗️ Architecture

### Tech Stack
- **Backend**: Elixir/OTP with GenServer-based monitoring processes
- **Web Interface**: Phoenix LiveView for real-time dashboards
- **Styling**: Tailwind CSS with custom dark theme
- **Charts**: Chart.js for interactive visualizations
- **Data Storage**: ETS tables for high-speed time series data
- **ML Framework**: Nx/Axon for machine learning pipelines

### System Components
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Data Sources   │    │   Elixir OTP     │    │   Phoenix Web   │
│                 │    │   Supervisors    │    │   LiveViews     │
├─────────────────┤    ├──────────────────┤    ├─────────────────┤
│ • Alpha Vantage │ -> │ • FinancialMon   │ -> │ • DashboardLive │
│ • Binance WS    │    │ • PoliticalMon   │    │ • FinancialLive │
│ • News APIs     │    │ • NaturalMon     │    │ • PoliticalLive │
│ • USGS          │    │ • ML Pipeline    │    │ • NaturalLive   │
│ • Weather APIs  │    │ • DataStore      │    │ • AnomaliesLive │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 📊 Dashboard Overview

### Main Dashboard
- **Global threat assessment** with color-coded risk levels
- **System health monitoring** (uptime, active streams, ML models)
- **Cross-monitor summaries** from all three monitoring systems
- **Recent anomalies feed** with real-time updates

### Financial Dashboard
- **Market overview cards**: Fear & Greed Index, Market Cap changes, Volatility
- **Interactive charts**: Crypto prices, stock indices, forex rates, commodities
- **Volume analysis**: Trading volume distribution across assets
- **Correlation matrix**: Real-time asset correlation tracking

### Political Dashboard
- **Sentiment analysis**: Overall, news, and social media sentiment scores
- **Breaking news feed**: Latest political developments with sentiment scoring
- **Social media trends**: Trending hashtags and discussion topics
- **Political events timeline**: Upcoming elections, summits, policy announcements

### Natural Events Dashboard
- **Event type filtering**: Earthquakes, weather, hurricanes, space weather
- **Recent earthquakes**: Magnitude, location, depth, tsunami warnings
- **Active hurricanes**: Category, wind speed, pressure, forecast tracks
- **Space weather conditions**: Geomagnetic storms, solar wind data

## 🛠️ Installation & Setup

### Prerequisites
- Elixir 1.14+ and Erlang/OTP 25+
- Phoenix 1.7+
- Node.js 16+ (for asset compilation)

### Quick Start
1. **Clone and setup**:
   ```bash
   git clone <repository>
   cd global_pulse
   mix deps.get
   ```

2. **Start the server**:
   ```bash
   ./start_server.sh
   ```

3. **Access dashboards**:
   - Main Dashboard: http://localhost:4000
   - Financial: http://localhost:4000/financial
   - Political: http://localhost:4000/political
   - Natural Events: http://localhost:4000/natural
   - Anomalies: http://localhost:4000/anomalies

### API Keys (Optional)
For enhanced data sources, set environment variables:
- `ALPHA_VANTAGE_API_KEY`: For enhanced stock data
- `NEWS_API_KEY`: For political news feeds
- `OPENWEATHER_API_KEY`: For weather data

*Note: The system includes mock data generators, so it will work without API keys for demonstration purposes.*

## 🎛️ Configuration

### Monitor Polling Intervals
- Financial Monitor: 60 seconds
- Political Monitor: 5 minutes  
- Natural Events Monitor: 3 minutes
- ML Pipeline: 5 minutes
- Inflection Detector: 1 minute

### Anomaly Detection Thresholds
- Price change threshold: 5%
- Volume spike threshold: 100M+
- Earthquake magnitude: 4.5+
- Sentiment shift threshold: 0.7

## 🔍 Machine Learning Features

### Inflection Point Detection
- **Time series analysis**: Detects sudden changes in data trends
- **Multi-modal correlation**: Identifies cross-domain event relationships
- **Pattern recognition**: Learns from historical inflection points
- **Confidence scoring**: Quantifies prediction reliability

### Anomaly Scoring Algorithm
```
Anomaly Score = Σ(Domain Weight × Severity × Recency × Correlation)
```

### Predictive Models
- **Market volatility prediction**: Based on news sentiment + natural events
- **Political instability forecasting**: Social media trends + economic indicators
- **Natural disaster impact assessment**: Historical patterns + current conditions

## 🚨 Alert System

### Severity Levels
- **🔴 Critical**: Immediate attention required (market crashes, major earthquakes)
- **🟠 High**: Significant events (political upheaval, severe weather)
- **🟡 Medium**: Notable changes (sentiment shifts, minor earthquakes)
- **🔵 Low**: Informational (trend changes, routine events)

### Real-time Notifications
- Phoenix PubSub broadcasts for live dashboard updates
- WebSocket connections for instant anomaly alerts
- Color-coded threat level indicators

## 📈 Use Cases

### Financial Traders
- Monitor multiple asset classes simultaneously
- Detect market anomalies before they become obvious
- Correlation analysis for risk management
- Sentiment-driven trading signals

### Risk Analysts
- Cross-domain event correlation analysis
- Early warning system for systemic risks
- Historical pattern recognition
- Multi-factor risk assessment

### Researchers
- Real-time data collection and analysis
- Machine learning model training and validation
- Social-political-economic event correlation studies
- Natural disaster impact assessment

## 🔧 Development

### Adding New Monitors
1. Create monitor GenServer in `lib/global_pulse/monitors/`
2. Add to supervision tree in `application.ex`
3. Implement data fetching and anomaly detection
4. Create corresponding LiveView dashboard

### Extending ML Pipeline
1. Add new models to `lib/global_pulse/ml_pipeline.ex`
2. Implement feature extraction from raw data
3. Create prediction functions
4. Add model evaluation metrics

### Custom Dashboards
- LiveView components in `lib/global_pulse_web/live/`
- Real-time updates via Phoenix PubSub
- Interactive charts with Chart.js hooks
- Responsive design with Tailwind CSS

## 📄 License

MIT License - See LICENSE file for details

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Implement changes with tests
4. Submit a pull request

---

*Built with ❤️ using Elixir, Phoenix, and machine learning to monitor our interconnected world.*

