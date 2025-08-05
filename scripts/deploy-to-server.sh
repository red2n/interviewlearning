#!/bin/bash

# Redis Bloom Filter Application - Server Deployment Script
# This script sets up the complete Redis Bloom filter application on a remote server
# Usage: ./deploy-to-server.sh [server] [port] [user]

set -e

# Configuration
SERVER_HOST="${1:-stay-white.ad.local}"
SERVER_USER="${2:-stayuser}"
APP_PORT="${3:-3000}"
REDIS_PORT="${4:-6379}"
LOCAL_PROJECT_DIR="$(pwd)"
REMOTE_PROJECT_DIR="/home/${SERVER_USER}/redis-bloom-app"
DEPLOYMENT_ARCHIVE="redis-bloom-deployment.tar.gz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if we can reach the server
    if ! ssh -o ConnectTimeout=10 "${SERVER_USER}@${SERVER_HOST}" "echo 'Connection successful'" > /dev/null 2>&1; then
        log_error "Cannot connect to server ${SERVER_USER}@${SERVER_HOST}"
        log_info "Please ensure:"
        log_info "  1. SSH access is configured"
        log_info "  2. Server is reachable"
        log_info "  3. User has appropriate permissions"
        exit 1
    fi

    log_info "Server connection verified"
}

# Function to create deployment archive
create_deployment_archive() {
    log_info "Creating deployment archive..."

    # Create temporary directory for deployment
    TEMP_DIR=$(mktemp -d)
    DEPLOY_DIR="${TEMP_DIR}/redis-bloom-app"

    # Create directory structure
    mkdir -p "${DEPLOY_DIR}"
    mkdir -p "${DEPLOY_DIR}/src"
    mkdir -p "${DEPLOY_DIR}/scripts"
    mkdir -p "${DEPLOY_DIR}/config"
    mkdir -p "${DEPLOY_DIR}/docs"

    # Copy application files
    cp package.json "${DEPLOY_DIR}/"
    cp tsconfig.json "${DEPLOY_DIR}/"
    cp -r src/* "${DEPLOY_DIR}/src/"

    # Copy scripts
    cp scripts/setup-redis-bloom.sh "${DEPLOY_DIR}/scripts/"
    cp scripts/monitor-cache.sh "${DEPLOY_DIR}/scripts/"

    # Copy configuration files
    cp config/redis-cache.conf "${DEPLOY_DIR}/config/" 2>/dev/null || true
    cp config/docker-compose.cache.yml "${DEPLOY_DIR}/config/" 2>/dev/null || true

    # Copy documentation
    cp README.md "${DEPLOY_DIR}/docs/" 2>/dev/null || true
    cp docs/DIAGNOSTICS.md "${DEPLOY_DIR}/docs/" 2>/dev/null || true
    cp docs/CACHE-PURGING-GUIDE.md "${DEPLOY_DIR}/docs/" 2>/dev/null || true
    cp docs/DEPLOYMENT-GUIDE.md "${DEPLOY_DIR}/docs/" 2>/dev/null || true

    # Create deployment-specific files
    create_server_setup_script "${DEPLOY_DIR}"
    create_systemd_service "${DEPLOY_DIR}"
    create_nginx_config "${DEPLOY_DIR}"
    create_environment_config "${DEPLOY_DIR}"

    # Create archive
    cd "${TEMP_DIR}"
    tar -czf "${LOCAL_PROJECT_DIR}/${DEPLOYMENT_ARCHIVE}" redis-bloom-app/
    cd "${LOCAL_PROJECT_DIR}"

    # Cleanup
    rm -rf "${TEMP_DIR}"

    log_info "Deployment archive created: ${DEPLOYMENT_ARCHIVE}"
}

# Function to create server setup script
create_server_setup_script() {
    local deploy_dir="$1"

    cat > "${deploy_dir}/server-setup.sh" << 'EOF'
#!/bin/bash

# Server Setup Script for Redis Bloom Application

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Get configuration
APP_PORT="${1:-3000}"
REDIS_PORT="${2:-6379}"
PROJECT_DIR="${3:-/home/$(whoami)/redis-bloom-app}"

log_info "Setting up Redis Bloom application..."
log_info "  - App Port: $APP_PORT"
log_info "  - Redis Port: $REDIS_PORT"
log_info "  - Project Dir: $PROJECT_DIR"

# Update system packages
log_info "Updating system packages..."
sudo apt update

# Install Node.js and npm
log_info "Installing Node.js and npm..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    log_info "Node.js already installed: $(node --version)"
fi

# Install Docker
log_info "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $(whoami)
    rm get-docker.sh
else
    log_info "Docker already installed: $(docker --version)"
fi

# Install Docker Compose
log_info "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo apt-get install -y docker-compose-plugin
else
    log_info "Docker Compose already installed: $(docker-compose --version)"
fi

# Install Redis CLI
log_info "Installing Redis CLI..."
sudo apt-get install -y redis-tools

# Setup project
cd "$PROJECT_DIR"

# Install Node.js dependencies
log_info "Installing Node.js dependencies..."
npm install

# Build TypeScript
log_info "Building TypeScript..."
npm run build

# Make scripts executable
chmod +x scripts/*.sh

# Setup Redis using Docker
log_info "Setting up Redis Stack with Docker..."
cd config
if [ -f "docker-compose.cache.yml" ]; then
    docker-compose -f docker-compose.cache.yml up -d
else
    # Fallback to basic Redis Stack
    docker run -d \
        --name redis-stack \
        -p ${REDIS_PORT}:6379 \
        -p 8001:8001 \
        --restart unless-stopped \
        redis/redis-stack:latest
fi

# Wait for Redis to be ready
log_info "Waiting for Redis to be ready..."
sleep 10

# Test Redis connection
if redis-cli -p ${REDIS_PORT} ping | grep -q PONG; then
    log_info "Redis is ready and responding"
else
    log_error "Redis is not responding"
    exit 1
fi

# Test application
log_info "Testing application..."
timeout 30 node dist/index.js || log_info "Application test completed"

# Setup systemd service (optional)
if [ -f "redis-bloom-app.service" ]; then
    log_info "Setting up systemd service..."
    sudo cp redis-bloom-app.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable redis-bloom-app
    sudo systemctl start redis-bloom-app
fi

# Setup nginx reverse proxy (optional)
if [ -f "nginx-redis-bloom.conf" ] && command -v nginx &> /dev/null; then
    log_info "Setting up nginx reverse proxy..."
    sudo cp nginx-redis-bloom.conf /etc/nginx/sites-available/redis-bloom-app
    sudo ln -sf /etc/nginx/sites-available/redis-bloom-app /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
fi

log_info "Server setup completed successfully!"
log_info "Application will be available on port $APP_PORT"
log_info "Redis will be available on port $REDIS_PORT"
log_info ""
log_info "Next steps:"
log_info "  1. Test the application: curl http://localhost:$APP_PORT"
log_info "  2. Monitor cache: ./scripts/monitor-cache.sh stats"
log_info "  3. View logs: journalctl -u redis-bloom-app -f"

EOF

    chmod +x "${deploy_dir}/server-setup.sh"
}

# Function to create systemd service
create_systemd_service() {
    local deploy_dir="$1"

    cat > "${deploy_dir}/redis-bloom-app.service" << EOF
[Unit]
Description=Redis Bloom Filter Application
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=${SERVER_USER}
WorkingDirectory=${REMOTE_PROJECT_DIR}
Environment=NODE_ENV=production
Environment=PORT=${APP_PORT}
Environment=REDIS_URL=redis://localhost:${REDIS_PORT}
ExecStart=/usr/bin/node dist/web-server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
}

# Function to create nginx configuration
create_nginx_config() {
    local deploy_dir="$1"

    cat > "${deploy_dir}/nginx-redis-bloom.conf" << EOF
server {
    listen 80;
    server_name ${SERVER_HOST};

    location / {
        proxy_pass http://localhost:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    location /api/ {
        proxy_pass http://localhost:${APP_PORT}/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /health {
        proxy_pass http://localhost:${APP_PORT}/health;
        access_log off;
    }
}
EOF
}

# Function to create environment configuration
create_environment_config() {
    local deploy_dir="$1"

    cat > "${deploy_dir}/.env.production" << EOF
# Production Environment Configuration
NODE_ENV=production
PORT=${APP_PORT}
REDIS_URL=redis://localhost:${REDIS_PORT}
REDIS_HOST=localhost
REDIS_PORT=${REDIS_PORT}

# Logging
LOG_LEVEL=info
LOG_PRETTY=false

# Cache Configuration
CACHE_TTL_DEFAULT=3600
CACHE_TTL_SESSION=1800
CACHE_TTL_API=600

# Application Configuration
APP_NAME=redis-bloom-app
APP_VERSION=1.0.0
EOF
}

# Function to deploy to server
deploy_to_server() {
    log_info "Deploying to server ${SERVER_USER}@${SERVER_HOST}..."

    # Copy deployment archive to server
    log_info "Copying deployment archive to server..."
    scp "${DEPLOYMENT_ARCHIVE}" "${SERVER_USER}@${SERVER_HOST}:/tmp/"

    # Extract and setup on server
    log_info "Extracting and setting up on server..."
    ssh "${SERVER_USER}@${SERVER_HOST}" << EOF
        set -e

        # Remove existing deployment
        rm -rf "${REMOTE_PROJECT_DIR}"

        # Extract new deployment
        cd /tmp
        tar -xzf "${DEPLOYMENT_ARCHIVE}"
        mv redis-bloom-app "${REMOTE_PROJECT_DIR}"

        # Run server setup
        cd "${REMOTE_PROJECT_DIR}"
        ./server-setup.sh "${APP_PORT}" "${REDIS_PORT}" "${REMOTE_PROJECT_DIR}"
EOF

    log_info "Deployment completed successfully!"
}

# Function to create web server for remote access
create_web_server() {
    log_info "Creating web server for remote access..."

    cat > "src/web-server.ts" << 'EOF'
import express from 'express';
import { createClient } from 'redis';
import pino from 'pino';
import { RedisCacheManager } from './advanced-cache-manager.js';

const app = express();
const port = process.env.PORT || 3000;

const logger = pino({
    level: process.env.LOG_LEVEL || 'info',
    transport: process.env.LOG_PRETTY === 'true' ? {
        target: 'pino-pretty',
        options: { colorize: true }
    } : undefined
});

// Initialize Redis client
const redisClient = createClient({
    url: process.env.REDIS_URL || 'redis://localhost:6379'
});

const cacheManager = new RedisCacheManager(process.env.REDIS_URL);

app.use(express.json());

// Middleware to log requests
app.use((req, res, next) => {
    logger.info({ method: req.method, url: req.url }, 'HTTP Request');
    next();
});

// Health check endpoint
app.get('/health', async (req, res) => {
    try {
        await redisClient.ping();
        res.json({
            status: 'healthy',
            timestamp: new Date().toISOString(),
            redis: 'connected',
            uptime: process.uptime()
        });
    } catch (error) {
        res.status(500).json({
            status: 'unhealthy',
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Bloom filter endpoints
app.post('/api/bloom/create', async (req, res) => {
    try {
        const { name, errorRate = 0.01, capacity = 10000, ttl } = req.body;

        if (!name) {
            return res.status(400).json({ error: 'Bloom filter name is required' });
        }

        if (ttl) {
            await cacheManager.createBloomCache(name, errorRate, capacity, ttl);
        } else {
            await redisClient.bf.reserve(name, errorRate, capacity);
        }

        logger.info({ name, errorRate, capacity, ttl }, 'Bloom filter created');
        res.json({ success: true, name, errorRate, capacity, ttl });
    } catch (error) {
        logger.error({ error: error.message }, 'Error creating Bloom filter');
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/bloom/:name/add', async (req, res) => {
    try {
        const { name } = req.params;
        const { items, ttl } = req.body;

        if (!items || (!Array.isArray(items) && typeof items !== 'string')) {
            return res.status(400).json({ error: 'Items are required (string or array)' });
        }

        let results;
        if (Array.isArray(items)) {
            results = await redisClient.bf.mAdd(name, items);
        } else {
            results = await redisClient.bf.add(name, items);
        }

        if (ttl) {
            await redisClient.expire(name, ttl);
        }

        logger.info({ name, items, results }, 'Items added to Bloom filter');
        res.json({ success: true, results });
    } catch (error) {
        logger.error({ error: error.message }, 'Error adding to Bloom filter');
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/bloom/:name/check', async (req, res) => {
    try {
        const { name } = req.params;
        const { items } = req.body;

        if (!items || (!Array.isArray(items) && typeof items !== 'string')) {
            return res.status(400).json({ error: 'Items are required (string or array)' });
        }

        let results;
        if (Array.isArray(items)) {
            results = await redisClient.bf.mExists(name, items);
        } else {
            results = await redisClient.bf.exists(name, items);
        }

        logger.info({ name, items, results }, 'Bloom filter check performed');
        res.json({ success: true, results });
    } catch (error) {
        logger.error({ error: error.message }, 'Error checking Bloom filter');
        res.status(500).json({ error: error.message });
    }
});

// Cache management endpoints
app.get('/api/cache/stats', async (req, res) => {
    try {
        await cacheManager.connect();
        const stats = await cacheManager.getCacheStats();
        await cacheManager.disconnect();

        res.json({ success: true, stats });
    } catch (error) {
        logger.error({ error: error.message }, 'Error getting cache stats');
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/cache/set', async (req, res) => {
    try {
        const { key, value, ttl } = req.body;

        if (!key || value === undefined) {
            return res.status(400).json({ error: 'Key and value are required' });
        }

        await cacheManager.connect();
        if (ttl) {
            await cacheManager.setWithTTL(key, value, ttl);
        } else {
            await redisClient.set(key, JSON.stringify(value));
        }
        await cacheManager.disconnect();

        logger.info({ key, ttl }, 'Cache entry set');
        res.json({ success: true });
    } catch (error) {
        logger.error({ error: error.message }, 'Error setting cache');
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/cache/:key', async (req, res) => {
    try {
        const { key } = req.params;
        const { refreshTTL } = req.query;

        await cacheManager.connect();
        let value;
        if (refreshTTL) {
            value = await cacheManager.getWithRefresh(key, parseInt(refreshTTL));
        } else {
            const rawValue = await redisClient.get(key);
            value = rawValue ? JSON.parse(rawValue) : null;
        }
        await cacheManager.disconnect();

        res.json({ success: true, value });
    } catch (error) {
        logger.error({ error: error.message }, 'Error getting cache');
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/cache/:pattern', async (req, res) => {
    try {
        const { pattern } = req.params;

        await cacheManager.connect();
        const deletedCount = await cacheManager.cleanup(pattern);
        await cacheManager.disconnect();

        logger.info({ pattern, deletedCount }, 'Cache cleanup performed');
        res.json({ success: true, deletedCount });
    } catch (error) {
        logger.error({ error: error.message }, 'Error cleaning cache');
        res.status(500).json({ error: error.message });
    }
});

// Demo endpoints
app.post('/api/demo/bloom', async (req, res) => {
    try {
        await cacheManager.connect();

        // Create demo bloom filter
        await cacheManager.createBloomCache('demo:search', 0.01, 1000, 3600);

        // Add demo data
        const searchTerms = ['redis', 'bloom filter', 'cache', 'nosql', 'database'];
        for (const term of searchTerms) {
            await redisClient.bf.add('demo:search', term);
        }

        // Test some checks
        const checkTerms = ['redis', 'mysql', 'cache', 'unknown'];
        const results = await redisClient.bf.mExists('demo:search', checkTerms);

        await cacheManager.disconnect();

        logger.info({ searchTerms, checkTerms, results }, 'Demo bloom filter created');
        res.json({
            success: true,
            added: searchTerms,
            checked: checkTerms.map((term, index) => ({
                term,
                exists: results[index]
            }))
        });
    } catch (error) {
        logger.error({ error: error.message }, 'Error creating demo');
        res.status(500).json({ error: error.message });
    }
});

// Static file serving for documentation
app.get('/', (req, res) => {
    res.send(`
        <html>
            <head><title>Redis Bloom Filter Application</title></head>
            <body>
                <h1>Redis Bloom Filter Application</h1>
                <h2>Available Endpoints:</h2>
                <ul>
                    <li><strong>GET /health</strong> - Health check</li>
                    <li><strong>POST /api/bloom/create</strong> - Create bloom filter</li>
                    <li><strong>POST /api/bloom/:name/add</strong> - Add items to bloom filter</li>
                    <li><strong>POST /api/bloom/:name/check</strong> - Check items in bloom filter</li>
                    <li><strong>GET /api/cache/stats</strong> - Get cache statistics</li>
                    <li><strong>POST /api/cache/set</strong> - Set cache entry</li>
                    <li><strong>GET /api/cache/:key</strong> - Get cache entry</li>
                    <li><strong>DELETE /api/cache/:pattern</strong> - Clean cache by pattern</li>
                    <li><strong>POST /api/demo/bloom</strong> - Create demo bloom filter</li>
                </ul>
                <h2>Usage Examples:</h2>
                <pre>
# Test health
curl http://localhost:${port}/health

# Create demo
curl -X POST http://localhost:${port}/api/demo/bloom

# Create bloom filter
curl -X POST -H "Content-Type: application/json" \\
  -d '{"name":"test","errorRate":0.01,"capacity":1000,"ttl":3600}' \\
  http://localhost:${port}/api/bloom/create

# Add items
curl -X POST -H "Content-Type: application/json" \\
  -d '{"items":["item1","item2","item3"]}' \\
  http://localhost:${port}/api/bloom/test/add

# Check items
curl -X POST -H "Content-Type: application/json" \\
  -d '{"items":["item1","item4"]}' \\
  http://localhost:${port}/api/bloom/test/check
                </pre>
            </body>
        </html>
    `);
});

// Start server
async function startServer() {
    try {
        await redisClient.connect();
        await cacheManager.connect();

        logger.info('Connected to Redis');

        app.listen(port, '0.0.0.0', () => {
            logger.info({ port }, `Server running on port ${port}`);
            logger.info(`Access the application at: http://localhost:${port}`);
        });
    } catch (error) {
        logger.error({ error: error.message }, 'Failed to start server');
        process.exit(1);
    }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
    logger.info('Received SIGTERM, shutting down gracefully');
    await redisClient.quit();
    await cacheManager.disconnect();
    process.exit(0);
});

process.on('SIGINT', async () => {
    logger.info('Received SIGINT, shutting down gracefully');
    await redisClient.quit();
    await cacheManager.disconnect();
    process.exit(0);
});

startServer();
EOF
}

# Function to setup firewall rules
setup_firewall() {
    log_info "Setting up firewall rules on server..."

    ssh "${SERVER_USER}@${SERVER_HOST}" << EOF
        # Allow SSH (ensure we don't lock ourselves out)
        sudo ufw allow ssh

        # Allow application port
        sudo ufw allow ${APP_PORT}

        # Allow Redis port (only from localhost)
        sudo ufw allow from 127.0.0.1 to any port ${REDIS_PORT}

        # Allow HTTP/HTTPS if nginx is used
        sudo ufw allow 80
        sudo ufw allow 443

        # Enable firewall (if not already enabled)
        sudo ufw --force enable || true

        # Show status
        sudo ufw status
EOF
}

# Function to show connection instructions
show_connection_info() {
    log_info "Deployment completed successfully!"
    echo
    echo -e "${GREEN}=== Connection Information ===${NC}"
    echo -e "${BLUE}Server:${NC} ${SERVER_HOST}"
    echo -e "${BLUE}Application Port:${NC} ${APP_PORT}"
    echo -e "${BLUE}Redis Port:${NC} ${REDIS_PORT} (localhost only)"
    echo
    echo -e "${GREEN}=== Access URLs ===${NC}"
    echo -e "${BLUE}Application:${NC} http://${SERVER_HOST}:${APP_PORT}"
    echo -e "${BLUE}Health Check:${NC} http://${SERVER_HOST}:${APP_PORT}/health"
    echo -e "${BLUE}Demo:${NC} curl -X POST http://${SERVER_HOST}:${APP_PORT}/api/demo/bloom"
    echo
    echo -e "${GREEN}=== SSH Commands ===${NC}"
    echo -e "${BLUE}Connect to server:${NC} ssh ${SERVER_USER}@${SERVER_HOST}"
    echo -e "${BLUE}View logs:${NC} ssh ${SERVER_USER}@${SERVER_HOST} 'journalctl -u redis-bloom-app -f'"
    echo -e "${BLUE}Monitor cache:${NC} ssh ${SERVER_USER}@${SERVER_HOST} 'cd ${REMOTE_PROJECT_DIR} && ./scripts/monitor-cache.sh stats'"
    echo
    echo -e "${GREEN}=== Local Testing ===${NC}"
    echo -e "${BLUE}Test from your machine:${NC}"
    echo "  curl http://${SERVER_HOST}:${APP_PORT}/health"
    echo "  curl -X POST http://${SERVER_HOST}:${APP_PORT}/api/demo/bloom"
    echo
    echo -e "${YELLOW}Note: Make sure port ${APP_PORT} is open in your network/firewall settings${NC}"
}

# Main deployment function
main() {
    log_info "Starting Redis Bloom Application deployment..."
    log_info "Target: ${SERVER_USER}@${SERVER_HOST}"
    log_info "Ports: App=${APP_PORT}, Redis=${REDIS_PORT}"

    # Add express dependency
    if ! grep -q '"express"' package.json; then
        log_info "Adding Express.js dependency..."
        npm install express @types/express
    fi

    # Create web server
    create_web_server

    # Build the project
    log_info "Building project..."
    npm run build

    # Check prerequisites
    check_prerequisites

    # Create deployment package
    create_deployment_archive

    # Deploy to server
    deploy_to_server

    # Setup firewall
    setup_firewall

    # Show connection information
    show_connection_info

    # Cleanup
    rm -f "${DEPLOYMENT_ARCHIVE}"

    log_info "Deployment process completed!"
}

# Show help if requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Redis Bloom Application - Server Deployment Script"
    echo
    echo "Usage: $0 [server] [app_port] [user] [redis_port]"
    echo
    echo "Arguments:"
    echo "  server      Target server hostname (default: stay-white.ad.local)"
    echo "  app_port    Application port (default: 3000)"
    echo "  user        SSH user (default: stayuser)"
    echo "  redis_port  Redis port (default: 6379)"
    echo
    echo "Examples:"
    echo "  $0                                    # Use all defaults"
    echo "  $0 myserver.com 8080 myuser          # Custom server and port"
    echo "  $0 stay-white.ad.local 3000 stayuser # Explicit defaults"
    echo
    echo "Prerequisites:"
    echo "  - SSH access to target server"
    echo "  - sudo privileges on target server"
    echo "  - Internet connection on target server"
    exit 0
fi

# Run main function
main "$@"
