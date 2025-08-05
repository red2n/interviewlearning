#!/bin/bash

# Docker deployment script for Redis Bloom Filter Application
# Usage: ./scripts/docker-deploy.sh

set -e

# Configuration
SERVER_HOST="stay-whit# View logs
echo "cd ~/redis-bloom-docker && docker compose logs -f"
echo
echo "# Restart services"
echo "cd ~/redis-bloom-docker && docker compose restart"
echo
echo "# Stop services"
echo "cd ~/redis-bloom-docker && docker compose down"
echo
echo "# Check status"
echo "cd ~/redis-bloom-docker && docker compose ps"
SERVER_USER="stayuser"
IMAGE_NAME="redis-bloom-app"
IMAGE_TAG="latest"
CONTAINER_NAME="redis-bloom-app"
APP_PORT="3000"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
log_info "Checking prerequisites..."
if ! command_exists docker; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command_exists docker || ! docker compose version >/dev/null 2>&1; then
    log_error "Docker Compose is not available. Please install Docker Compose first."
    exit 1
fi

# Build the Docker image locally
log_info "Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

if [ $? -eq 0 ]; then
    log_info "Docker image built successfully"
else
    log_error "Failed to build Docker image"
    exit 1
fi

# Save the image to a tar file
log_info "Saving Docker image to tar file..."
docker save "${IMAGE_NAME}:${IMAGE_TAG}" -o "${IMAGE_NAME}-${IMAGE_TAG}.tar"

# Compress the tar file
log_info "Compressing Docker image..."
gzip "${IMAGE_NAME}-${IMAGE_TAG}.tar"

# Create deployment package
log_info "Creating deployment package..."
tar -czf redis-bloom-docker-deployment.tar.gz \
    "${IMAGE_NAME}-${IMAGE_TAG}.tar.gz" \
    docker-compose.yml \
    config/ \
    scripts/setup-redis-bloom.sh \
    .env.example 2>/dev/null || true

# Upload to server
log_info "Uploading deployment package to server..."
scp redis-bloom-docker-deployment.tar.gz "${SERVER_USER}@${SERVER_HOST}:/tmp/"

# Deploy on server
log_info "Deploying on server..."
ssh "${SERVER_USER}@${SERVER_HOST}" << 'EOF'
    cd /tmp

    # Extract deployment package
    tar -xzf redis-bloom-docker-deployment.tar.gz

    # Create application directory
    mkdir -p ~/redis-bloom-docker
    cp docker-compose.yml ~/redis-bloom-docker/
    cp -r config ~/redis-bloom-docker/ 2>/dev/null || true
    cp scripts/setup-redis-bloom.sh ~/redis-bloom-docker/ 2>/dev/null || true

    # Load Docker image
    echo "Loading Docker image..."
    docker load -i redis-bloom-app-latest.tar.gz

    # Stop existing containers
    cd ~/redis-bloom-docker
    docker compose down 2>/dev/null || true

    # Start the application
    echo "Starting Redis Bloom Filter application..."
    docker compose up -d

    # Wait for services to be ready
    echo "Waiting for services to start..."
    sleep 10

    # Check if containers are running
    docker compose ps

    # Test the application
    echo "Testing application..."
    sleep 5
    curl -f http://localhost:3000/health && echo "✅ Application is healthy!" || echo "❌ Application health check failed"

    # Cleanup
    rm -f /tmp/redis-bloom-docker-deployment.tar.gz
    rm -f /tmp/redis-bloom-app-latest.tar.gz
    rm -f /tmp/docker-compose.yml
    rm -rf /tmp/config /tmp/scripts
EOF

# Cleanup local files
log_info "Cleaning up local files..."
rm -f "${IMAGE_NAME}-${IMAGE_TAG}.tar.gz"
rm -f redis-bloom-docker-deployment.tar.gz

# Test remote deployment
log_info "Testing remote deployment..."
sleep 2
if curl -f "http://${SERVER_HOST}:${APP_PORT}/health" >/dev/null 2>&1; then
    log_info "🎉 Deployment successful! Application is running at http://${SERVER_HOST}:${APP_PORT}"
else
    log_warn "Application may still be starting. Please wait a moment and try: curl http://${SERVER_HOST}:${APP_PORT}/health"
fi

echo
echo "=== Deployment Summary ==="
echo "✅ Docker image built: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "✅ Image uploaded to server: ${SERVER_HOST}"
echo "✅ Docker Compose deployment started"
echo "✅ Application URL: http://${SERVER_HOST}:${APP_PORT}"
echo "✅ Redis Stack URL: http://${SERVER_HOST}:8001 \(RedisInsight\)"
echo
echo "=== Server Management Commands ==="
echo "# Connect to server"
echo "ssh ${SERVER_USER}@${SERVER_HOST}"
echo
echo "# View logs"
echo "cd ~/redis-bloom-docker && docker compose logs -f"
echo
echo "# Restart services"
echo "cd ~/redis-bloom-docker && docker compose restart"
echo
echo "# Stop services"
echo "cd ~/redis-bloom-docker && docker compose down"
echo
echo "# Check status"
echo "cd ~/redis-bloom-docker && docker compose ps"
