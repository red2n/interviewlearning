#!/bin/bash

# Simple deployment script for Redis Bloom Application
# Usage: ./simple-deploy.sh

set # Start Redis if needed
echo "cd redis-bloom-app && ./scripts/setup-redis-bloom.sh"
echo
echo "# Start application"
echo "cd redis-bloom-app && PORT=${APP_PORT} npm run server"
echo
echo "# Monitor in background"
echo "cd redis-bloom-app && nohup npm run server > app.log 2>&1 &"nfiguration
SERVER_HOST="stay-white.ad.local"
SERVER_USER="stayuser"
APP_PORT="3000"
LOCAL_PROJECT_DIR="$(pwd)"
REMOTE_PROJECT_DIR="/home/${SERVER_USER}/redis-bloom-app"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Create deployment package
log_info "Creating deployment package..."
tar -czf redis-bloom-deployment.tar.gz \
    package.json \
    tsconfig.json \
    src/ \
    dist/ \
    scripts/setup-redis-bloom.sh \
    scripts/monitor-cache.sh \
    config/redis-cache.conf \
    config/docker-compose.cache.yml \
    README.md \
    docs/DIAGNOSTICS.md \
    docs/CACHE-PURGING-GUIDE.md \
    docs/DEPLOYMENT-GUIDE.md

# Upload to server
log_info "Uploading to server..."
scp redis-bloom-deployment.tar.gz "${SERVER_USER}@${SERVER_HOST}:/tmp/"

# Deploy on server
log_info "Deploying on server..."
ssh "${SERVER_USER}@${SERVER_HOST}" << 'EOF'
    set -e

    # Extract deployment
    cd /tmp
    rm -rf redis-bloom-app
    tar -xzf redis-bloom-deployment.tar.gz

    # Move to final location
    rm -rf /home/stayuser/redis-bloom-app
    mv package.json tsconfig.json src dist scripts/setup-redis-bloom.sh scripts/monitor-cache.sh config/redis-cache.conf config/docker-compose.cache.yml README.md docs/DIAGNOSTICS.md docs/CACHE-PURGING-GUIDE.md docs/DEPLOYMENT-GUIDE.md /home/stayuser/
    mkdir -p /home/stayuser/redis-bloom-app
    cd /home/stayuser
    mv package.json tsconfig.json src dist scripts config docs README.md redis-bloom-app/
    cd redis-bloom-app

    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        echo "Installing Node.js dependencies..."
        npm install
    fi

# Setup Redis if not running
    if ! redis-cli ping > /dev/null 2>&1; then
        echo "Setting up Redis Stack..."
        chmod +x scripts/setup-redis-bloom.sh
        ./scripts/setup-redis-bloom.sh
        sleep 10
    fi

    # Make scripts executable
    chmod +x scripts/monitor-cache.sh    echo "Deployment completed!"
    echo "To start the server:"
    echo "  ssh stayuser@stay-white.ad.local"
    echo "  cd redis-bloom-app"
    echo "  PORT=3000 npm run server"
EOF

# Cleanup
rm redis-bloom-deployment.tar.gz

log_info "Deployment completed!"
echo
echo -e "${GREEN}=== Next Steps ===${NC}"
echo "1. Connect to server: ssh ${SERVER_USER}@${SERVER_HOST}"
echo "2. Start application: cd redis-bloom-app && PORT=${APP_PORT} npm run server"
echo "3. Test from your machine: curl http://${SERVER_HOST}:${APP_PORT}/health"
echo
echo -e "${GREEN}=== Manual Server Commands ===${NC}"
echo "# Connect to server"
echo "ssh ${SERVER_USER}@${SERVER_HOST}"
echo
echo "# Start Redis if needed"
echo "cd redis-bloom-app && ./setup-redis-bloom.sh"
echo
echo "# Start application"
echo "cd redis-bloom-app && PORT=${APP_PORT} npm run server"
echo
echo "# Monitor in background"
echo "cd redis-bloom-app && nohup npm run server > app.log 2>&1 &"
