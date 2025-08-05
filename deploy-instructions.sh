#!/bin/bash
# Simple Docker Deployment Instructions for stay-white.ad.local

echo "🐳 Redis Bloom Filter Application - Manual Deployment Guide"
echo "============================================================"
echo
echo "📋 PREREQUISITES:"
echo "  ✅ Docker image built: redis-bloom-app:latest"
echo "  ✅ Docker image saved: redis-bloom-app.tar"
echo "  ✅ Target server: stay-white.ad.local"
echo "  ✅ User: stayuser"
echo
echo "🚀 DEPLOYMENT STEPS:"
echo
echo "1️⃣  TRANSFER FILES TO SERVER:"
echo "    scp redis-bloom-app.tar stayuser@stay-white.ad.local:~/"
echo "    scp docker-compose.yml stayuser@stay-white.ad.local:~/"
echo "    scp -r config/ stayuser@stay-white.ad.local:~/"
echo "    scp .env.example stayuser@stay-white.ad.local:~/"
echo
echo "2️⃣  SSH TO SERVER:"
echo "    ssh stayuser@stay-white.ad.local"
echo
echo "3️⃣  LOAD DOCKER IMAGE:"
echo "    docker load -i redis-bloom-app.tar"
echo
echo "4️⃣  SETUP ENVIRONMENT:"
echo "    cp .env.example .env"
echo "    # Edit .env file if needed"
echo
echo "5️⃣  START SERVICES:"
echo "    docker compose up -d"
echo
echo "6️⃣  VERIFY DEPLOYMENT:"
echo "    docker compose ps"
echo "    curl http://localhost:3000/health"
echo
echo "🌐 ACCESS URLS:"
echo "  • Application: http://stay-white.ad.local:3000"
echo "  • Redis Insight: http://stay-white.ad.local:8001"
echo "  • Health Check: http://stay-white.ad.local:3000/health"
echo
echo "📊 MANAGEMENT COMMANDS:"
echo "  • View logs: docker compose logs -f"
echo "  • Restart: docker compose restart"
echo "  • Stop: docker compose down"
echo
echo "📝 For detailed instructions, see: DOCKER-DEPLOYMENT-GUIDE.md"
echo
