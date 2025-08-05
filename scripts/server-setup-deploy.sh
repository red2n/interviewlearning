#!/bin/bash

# Comprehensive server setup and deployment script
# Usage: ./server-setup-deploy.sh

set -e

# Configuration
SERVER_HOST="stay-white.ad.local"
SERVER_USER="stayuser"
APP_PORT="3000"
REDIS_PORT="6379"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Build locally first
log_info "Building project locally..."
npm run build

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

# Setup server
log_info "Setting up server environment..."
ssh "${SERVER_USER}@${SERVER_HOST}" << 'EOF'
    set -e

    echo "Setting up server environment..."

    # Update system
    sudo apt update

    # Install Node.js 18
    if ! command -v node &> /dev/null; then
        echo "Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
    else
        echo "Node.js already installed: $(node --version)"
    fi

    # Install Docker
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
        echo "Docker installed. You may need to log out and back in for group changes to take effect."
    else
        echo "Docker already installed: $(docker --version)"
    fi

    # Install Redis CLI
    if ! command -v redis-cli &> /dev/null; then
        echo "Installing Redis CLI..."
        sudo apt-get install -y redis-tools
    else
        echo "Redis CLI already installed"
    fi

    echo "Server environment setup completed!"
EOF

# Deploy application
log_info "Deploying application..."
ssh "${SERVER_USER}@${SERVER_HOST}" << 'EOF'
    set -e

    # Extract deployment
    cd /tmp
    tar -xzf redis-bloom-deployment.tar.gz

    # Setup project directory
    PROJECT_DIR="/home/stayuser/redis-bloom-app"
    rm -rf "$PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"

    # Move files
    cp -r package.json tsconfig.json src dist setup-redis-bloom.sh monitor-cache.sh redis-cache.conf docker-compose.cache.yml README.md DIAGNOSTICS.md CACHE-PURGING-GUIDE.md "$PROJECT_DIR/"
    cd "$PROJECT_DIR"

    # Install Node.js dependencies
    echo "Installing Node.js dependencies..."
    npm install

    # Make scripts executable
    chmod +x setup-redis-bloom.sh monitor-cache.sh

    # Setup Redis Stack with Docker
    echo "Setting up Redis Stack..."

    # Stop any existing Redis containers
    docker stop redis-stack 2>/dev/null || true
    docker rm redis-stack 2>/dev/null || true

    # Start Redis Stack
    docker run -d \
        --name redis-stack \
        -p 6379:6379 \
        -p 8001:8001 \
        --restart unless-stopped \
        redis/redis-stack:latest

    # Wait for Redis to be ready
    echo "Waiting for Redis to be ready..."
    sleep 15

    # Test Redis connection
    if redis-cli ping | grep -q PONG; then
        echo "Redis is ready!"
    else
        echo "Redis setup failed!"
        exit 1
    fi

    # Test application
    echo "Testing application..."
    timeout 10 node dist/web-server.js || true

    echo "Deployment completed successfully!"
EOF

# Cleanup
rm redis-bloom-deployment.tar.gz

log_info "Deployment completed!"
echo
echo -e "${GREEN}=== Server Access Information ===${NC}"
echo "Server: ${SERVER_HOST}"
echo "User: ${SERVER_USER}"
echo "Application Port: ${APP_PORT}"
echo "Redis Port: ${REDIS_PORT}"
echo
echo -e "${GREEN}=== Start Application ===${NC}"
echo "Connect to server and start the application:"
echo "  ssh ${SERVER_USER}@${SERVER_HOST}"
echo "  cd redis-bloom-app"
echo "  PORT=${APP_PORT} node dist/web-server.js"
echo
echo -e "${GREEN}=== Background Startup ===${NC}"
echo "To run in background:"
echo "  ssh ${SERVER_USER}@${SERVER_HOST}"
echo "  cd redis-bloom-app"
echo "  nohup PORT=${APP_PORT} node dist/web-server.js > app.log 2>&1 &"
echo
echo -e "${GREEN}=== Test from Your Machine ===${NC}"
echo "Once started, test from your local machine:"
echo "  curl http://${SERVER_HOST}:${APP_PORT}/health"
echo "  curl -X POST http://${SERVER_HOST}:${APP_PORT}/api/demo/bloom"
echo
echo -e "${YELLOW}=== Firewall Note ===${NC}"
echo "Make sure port ${APP_PORT} is open on the server firewall!"
echo "You may need to configure firewall rules or check with your network admin."
echo
echo -e "${GREEN}=== Manual Commands ===${NC}"
echo "# SSH to server"
echo "ssh ${SERVER_USER}@${SERVER_HOST}"
echo
echo "# Check Redis status"
echo "redis-cli ping"
echo
echo "# Monitor Redis"
echo "cd redis-bloom-app && ./monitor-cache.sh stats"
echo
echo "# View application logs"
echo "tail -f redis-bloom-app/app.log"
