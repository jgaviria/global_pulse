#!/bin/bash

echo "🌍 Starting Global Pulse Monitoring System..."
echo "=============================================="

# Build assets
echo "📦 Building frontend assets..."
cd assets && npm install --silent 2>/dev/null || true
cd ..

echo "🚀 Starting Phoenix server on http://localhost:4000"
echo ""
echo "Available dashboards:"
echo "  • Overview: http://localhost:4000/"
echo "  • Financial: http://localhost:4000/financial"
echo "  • Political: http://localhost:4000/political"  
echo "  • Natural Events: http://localhost:4000/natural"
echo "  • Anomalies: http://localhost:4000/anomalies"
echo ""
echo "Press Ctrl+C to stop the server"
echo "=============================================="

mix phx.server