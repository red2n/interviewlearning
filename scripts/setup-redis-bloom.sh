#!/bin/bash

# Comprehensive Redis Bloom Setup Script
# This script sets up Redis with RedisBloom module for the Node.js application
# It includes multiple approaches: Docker (recommended), manual compilation, and system Redis

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Redis Bloom Comprehensive Setup Script${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Function to print colored output
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to setup via Docker (Recommended)
setup_docker_redis() {
    print_info "Setting up Redis Stack with Docker (Recommended approach)..."

    # Check if Docker is installed
    if ! command_exists docker; then
        print_error "Docker is not installed. Installing Docker..."

        # Update package index
        sudo apt update

        # Install required packages
        sudo apt install -y ca-certificates curl gnupg lsb-release

        # Add Docker's official GPG key
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

        # Set up the repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Install Docker Engine
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

        # Add current user to docker group
        sudo usermod -aG docker $USER

        print_warning "Docker installed. You may need to log out and back in for group changes to take effect."
        print_warning "Or run: newgrp docker"
    fi

    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_info "Starting Docker service..."
        sudo systemctl start docker
        sudo systemctl enable docker
    fi

    print_success "Docker is available and running"

    # Stop any existing Redis containers
    print_info "Stopping any existing Redis containers..."
    docker stop redis-stack 2>/dev/null || true
    docker rm redis-stack 2>/dev/null || true

    # Stop system Redis service if running
    print_info "Stopping system Redis service if running..."
    sudo systemctl stop redis-server 2>/dev/null || true

    # Pull and run Redis Stack with RedisBloom
    print_info "Pulling and starting Redis Stack container..."
    docker run -d \
        --name redis-stack \
        -p 6379:6379 \
        -p 8001:8001 \
        --restart unless-stopped \
        redis/redis-stack-server:latest

    # Wait for Redis to be ready
    print_info "Waiting for Redis to be ready..."
    sleep 5

    # Test Redis connection
    print_info "Testing Redis connection..."
    max_attempts=10
    attempt=1

    while [ $attempt -le $max_attempts ]; do
        if redis-cli ping &> /dev/null; then
            print_success "Redis is responding to ping"
            break
        else
            print_info "Attempt $attempt/$max_attempts: Waiting for Redis..."
            sleep 2
            ((attempt++))
        fi
    done

    if [ $attempt -gt $max_attempts ]; then
        print_error "Failed to connect to Redis after $max_attempts attempts"
        return 1
    fi

    # Check if RedisBloom module is loaded
    print_info "Checking if RedisBloom module is loaded..."
    if redis-cli MODULE LIST | grep -q "bf"; then
        print_success "RedisBloom module is loaded successfully"
    else
        print_error "RedisBloom module is not loaded"
        return 1
    fi

    # Test bloom filter operations
    print_info "Testing Bloom filter operations..."
    redis-cli BF.RESERVE test:bloom 0.01 1000 > /dev/null
    redis-cli BF.ADD test:bloom "test-item" > /dev/null
    if redis-cli BF.EXISTS test:bloom "test-item" | grep -q "1"; then
        print_success "Bloom filter operations are working"
        redis-cli DEL test:bloom > /dev/null
    else
        print_error "Bloom filter operations failed"
        return 1
    fi

    return 0
}

# Function to setup Redis manually (Alternative approach)
setup_manual_redis() {
    print_info "Setting up Redis manually with RedisBloom compilation..."

    # Install Redis server
    print_info "Installing Redis server..."
    sudo apt update
    sudo apt install -y redis-server redis-tools

    # Install build dependencies
    print_info "Installing build dependencies..."
    sudo apt install -y git build-essential python3 python3-pip cmake

    # Start Redis service
    sudo systemctl start redis-server
    sudo systemctl enable redis-server

    # Compile RedisBloom from source
    print_info "Compiling RedisBloom from source..."
    cd /tmp

    # Clean up any existing RedisBloom directory
    sudo rm -rf RedisBloom

    # Clone and build RedisBloom
    git clone https://github.com/RedisBloom/RedisBloom.git
    cd RedisBloom
    git submodule update --init --recursive
    make

    # Install the module
    sudo mkdir -p /usr/lib/redis/modules
    sudo cp bin/linux-x64-release/redisbloom.so /usr/lib/redis/modules/

    # Configure Redis to load the module
    print_info "Configuring Redis to load RedisBloom module..."

    # Remove existing loadmodule directive if present
    sudo sed -i '/loadmodule.*redisbloom.so/d' /etc/redis/redis.conf

    # Add module loading and enable module commands
    echo "loadmodule /usr/lib/redis/modules/redisbloom.so" | sudo tee -a /etc/redis/redis.conf
    echo "enable-module-command yes" | sudo tee -a /etc/redis/redis.conf

    # Restart Redis to load the module
    print_info "Restarting Redis to load the module..."
    sudo systemctl restart redis-server

    # Wait for Redis to be ready
    sleep 3

    # Test if the module is loaded
    if redis-cli MODULE LIST | grep -q "bf"; then
        print_success "RedisBloom module loaded successfully"
        return 0
    else
        print_warning "Module loading failed, attempting dynamic loading..."

        # Try to load module dynamically
        if redis-cli MODULE LOAD /usr/lib/redis/modules/redisbloom.so 2>/dev/null; then
            print_success "RedisBloom module loaded dynamically"
            return 0
        else
            print_error "Failed to load RedisBloom module"
            return 1
        fi
    fi
}

# Function to install Redis CLI if not present
install_redis_cli() {
    if ! command_exists redis-cli; then
        print_info "Installing Redis CLI..."
        sudo apt update
        sudo apt install -y redis-tools
    fi
}

# Function to display final information
display_final_info() {
    echo ""
    print_success "🎉 Redis Stack with RedisBloom is ready!"
    echo ""
    echo -e "${BLUE}📋 Container Information:${NC}"
    echo "   Name: redis-stack"
    echo "   Redis Port: 6379"
    echo "   RedisInsight Port: 8001 (Web UI)"
    echo ""
    echo -e "${BLUE}🔧 Useful Commands:${NC}"
    echo "   Start container:    docker start redis-stack"
    echo "   Stop container:     docker stop redis-stack"
    echo "   View logs:          docker logs redis-stack"
    echo "   Redis CLI:          redis-cli"
    echo "   Remove container:   docker rm redis-stack"
    echo ""
    echo -e "${BLUE}🌐 Access RedisInsight (Web UI):${NC} http://localhost:8001"
    echo ""
    echo -e "${GREEN}✨ You can now run your Node.js application with: npm start${NC}"
}

# Main execution
main() {
    # Install Redis CLI first (needed for testing)
    install_redis_cli

    # Try Docker approach first (recommended)
    print_info "Attempting Docker setup (recommended)..."
    if setup_docker_redis; then
        display_final_info
        return 0
    fi

    print_warning "Docker setup failed, trying manual compilation approach..."

    # If Docker fails, try manual approach
    if setup_manual_redis; then
        echo ""
        print_success "🎉 Redis with RedisBloom is ready (manual setup)!"
        echo ""
        echo -e "${BLUE}📋 Redis Information:${NC}"
        echo "   Redis Port: 6379"
        echo "   Service: redis-server"
        echo ""
        echo -e "${BLUE}🔧 Useful Commands:${NC}"
        echo "   Start Redis:        sudo systemctl start redis-server"
        echo "   Stop Redis:         sudo systemctl stop redis-server"
        echo "   Redis Status:       sudo systemctl status redis-server"
        echo "   Redis CLI:          redis-cli"
        echo "   View Logs:          sudo journalctl -u redis-server"
        echo ""
        echo -e "${GREEN}✨ You can now run your Node.js application with: npm start${NC}"
        return 0
    fi

    print_error "Both Docker and manual setup approaches failed!"
    echo ""
    echo -e "${YELLOW}💡 Manual troubleshooting steps:${NC}"
    echo "1. Check if ports 6379 is available: sudo netstat -tlnp | grep 6379"
    echo "2. Check Redis logs: sudo journalctl -u redis-server"
    echo "3. Try running Redis manually: redis-server --loadmodule /path/to/redisbloom.so"
    echo "4. Ensure all dependencies are installed: sudo apt install build-essential cmake python3"
    echo ""
    exit 1
}

# Run main function
main
