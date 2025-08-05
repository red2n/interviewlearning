# Redis Bloom Filter Application

[![CI/CD Pipeline](https://github.com/red2n/interviewlearning/workflows/CI/CD%20Pipeline/badge.svg)](https://github.com/red2n/interviewlearning/actions)
[![Build Status](https://github.com/red2n/interviewlearning/workflows/Build%20Status/badge.svg)](https://github.com/red2n/interviewlearning/actions)
[![Open in VS Code](https://img.shields.io/badge/Open%20in-VS%20Code-blue?style=flat-square&logo=visual-studio-code)](https://vscode.dev/github/red2n/interviewlearning)

A comprehensive Node.js/TypeScript application demonstrating Redis Bloom filters with auto-purging cache capabilities, web API interface, and server deployment automation.

## 🚀 Features

- **Redis Bloom Filters**: Create, add items, and check membership with configurable error rates
- **Cache Management**: TTL-based caching with multiple purging strategies
- **Web API**: RESTful endpoints for all operations with interactive web interface
- **Auto-Purging**: Memory-based eviction, TTL expiration, and scheduled cleanup
- **Real-time Monitoring**: Cache statistics and health monitoring
- **Server Deployment**: Automated deployment scripts for production setup
- **Comprehensive Documentation**: Detailed guides for setup, usage, and troubleshooting

## 📁 Project Structure

```
redis-bloom-app/
├── src/                           # TypeScript source code
│   ├── index.ts                   # Main Bloom filter demo
│   ├── web-server.ts              # Express web server
│   ├── advanced-cache-manager.ts  # Cache management class
│   └── types/
│       └── redis.d.ts             # Redis type definitions
├── scripts/                       # Shell scripts
│   ├── setup-redis-bloom.sh       # Redis setup with multiple fallbacks
│   ├── monitor-cache.sh           # Real-time cache monitoring
│   ├── deploy-to-server.sh        # Comprehensive deployment script
│   ├── server-setup-deploy.sh     # Simple deployment with server setup
│   └── simple-deploy.sh           # Basic file transfer deployment
├── config/                        # Configuration files
│   ├── redis-cache.conf           # Redis server configuration
│   └── docker-compose.cache.yml   # Docker Compose for Redis Stack
├── docs/                          # Documentation
│   ├── DIAGNOSTICS.md             # Troubleshooting guide
│   ├── CACHE-PURGING-GUIDE.md     # Cache management documentation
│   └── DEPLOYMENT-GUIDE.md        # Server deployment guide
├── dist/                          # Compiled JavaScript (generated)
├── package.json                   # Node.js dependencies and scripts
├── tsconfig.json                  # TypeScript configuration
└── README.md                      # This file
```

## 🛠️ Quick Start

### Prerequisites

- **Node.js** 18+ and npm
- **Docker** (recommended) or Redis Server
- **TypeScript** (installed via npm)

### Local Setup

1. **Install Dependencies**
   ```bash
   npm install
   ```

2. **Setup Redis Stack**
   ```bash
   chmod +x scripts/setup-redis-bloom.sh
   ./scripts/setup-redis-bloom.sh
   ```

3. **Build and Run**
   ```bash
   npm run build
   npm start                    # Run Bloom filter demo
   npm run server              # Start web server
   ```

4. **Test the Application**
   ```bash
   # Health check
   curl http://localhost:3000/health

   # Create demo bloom filter
   curl -X POST http://localhost:3000/api/demo/bloom

   # Open web interface
   open http://localhost:3000
   ```

## 🌐 Web API

### Available Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | Interactive web interface |
| `GET` | `/health` | Health check and status |
| `POST` | `/api/demo/bloom` | Create demo bloom filter |
| `POST` | `/api/bloom/create` | Create new bloom filter |
| `POST` | `/api/bloom/:name/add` | Add items to bloom filter |
| `POST` | `/api/bloom/:name/check` | Check items in bloom filter |
| `GET` | `/api/cache/stats` | Get cache statistics |
| `POST` | `/api/cache/set` | Set cache entry with TTL |
| `GET` | `/api/cache/:key` | Get cache entry |
| `DELETE` | `/api/cache/:pattern` | Clean cache by pattern |

### API Examples

```bash
# Create bloom filter with TTL
curl -X POST -H "Content-Type: application/json"
  -d '{"name":"search","errorRate":0.01,"capacity":1000,"ttl":3600}'
  http://localhost:3000/api/bloom/create

# Add items
curl -X POST -H "Content-Type: application/json"
  -d '{"items":["redis","bloom","filter"]}'
  http://localhost:3000/api/bloom/search/add

# Check items
curl -X POST -H "Content-Type: application/json"
  -d '{"items":["redis","mysql"]}'
  http://localhost:3000/api/bloom/search/check

# Set cache with 5-minute TTL
curl -X POST -H "Content-Type: application/json"
  -d '{"key":"user:123","value":{"name":"John"},"ttl":300}'
  http://localhost:3000/api/cache/set
```

## 🚢 Server Deployment

### Automated Deployment

Deploy to your server with a single command:

```bash
chmod +x scripts/server-setup-deploy.sh
./scripts/server-setup-deploy.sh
```

This will:
- Install Node.js, Docker, and Redis CLI on the server
- Deploy application files
- Setup Redis Stack with Docker
- Install dependencies and build the project
- Configure and test the setup

### Manual Deployment Steps

1. **Prepare for Deployment**
   ```bash
   npm run build
   chmod +x scripts/simple-deploy.sh
   ./scripts/simple-deploy.sh
   ```

2. **Connect to Server**
   ```bash
   ssh stayuser@stay-white.ad.local
   cd redis-bloom-app
   ```

3. **Start Application**
   ```bash
   # Foreground (for testing)
   PORT=3000 node dist/web-server.js

   # Background (for production)
   nohup PORT=3000 node dist/web-server.js > app.log 2>&1 &
   ```

4. **Test Remote Access**
   ```bash
   curl http://stay-white.ad.local:3000/health
   ```

## 📊 Monitoring and Management

### Cache Monitoring

```bash
# Real-time statistics
./scripts/monitor-cache.sh stats

# Live monitoring for 2 minutes
./scripts/monitor-cache.sh monitor 120

# Auto-purging test
./scripts/monitor-cache.sh test

# Create demo data
./scripts/monitor-cache.sh demo
```

### Application Monitoring

```bash
# View application logs
tail -f app.log

# Check process status
ps aux | grep node

# Monitor Redis
redis-cli info memory
docker logs redis-stack
```

## 🔧 Configuration

### Environment Variables

```bash
PORT=3000                    # Application port
REDIS_URL=redis://localhost:6379  # Redis connection URL
NODE_ENV=production          # Environment mode
LOG_LEVEL=info              # Logging level
```

### Redis Configuration

The application supports multiple Redis configurations:

- **Docker Redis Stack** (recommended): Includes RedisBloom, RedisJSON, RedisTimeSeries
- **System Redis** with manual RedisBloom compilation
- **Custom Redis** with configuration file

See [`config/redis-cache.conf`](config/redis-cache.conf) for Redis server settings.

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [DIAGNOSTICS.md](docs/DIAGNOSTICS.md) | Troubleshooting guide with common issues and solutions |
| [CACHE-PURGING-GUIDE.md](docs/CACHE-PURGING-GUIDE.md) | Comprehensive cache management and auto-purging strategies |
| [DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md) | Detailed server deployment instructions |

## 🔨 Scripts Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| [`setup-redis-bloom.sh`](scripts/setup-redis-bloom.sh) | Setup Redis with RedisBloom module | `./scripts/setup-redis-bloom.sh` |
| [`monitor-cache.sh`](scripts/monitor-cache.sh) | Real-time cache monitoring and testing | `./scripts/monitor-cache.sh [command]` |
| [`deploy-to-server.sh`](scripts/deploy-to-server.sh) | Comprehensive deployment with systemd/nginx | `./scripts/deploy-to-server.sh [server] [port] [user]` |
| [`server-setup-deploy.sh`](scripts/server-setup-deploy.sh) | Simple deployment with server setup | `./scripts/server-setup-deploy.sh` |
| [`simple-deploy.sh`](scripts/simple-deploy.sh) | Basic file transfer deployment | `./scripts/simple-deploy.sh` |

### Script Examples

```bash
# Setup Redis locally
./scripts/setup-redis-bloom.sh

# Monitor cache for 5 minutes
./scripts/monitor-cache.sh monitor 300

# Deploy to custom server
./scripts/deploy-to-server.sh myserver.com 8080 myuser

# Simple deployment to default server
./scripts/server-setup-deploy.sh
```

## 🧪 Testing

### Local Testing

```bash
# Build and test basic functionality
npm run build
npm start

# Test web server
PORT=3001 npm run server &
curl http://localhost:3001/health
curl -X POST http://localhost:3001/api/demo/bloom
```

### Production Testing

```bash
# Test after deployment
curl http://your-server:3000/health
curl -X POST http://your-server:3000/api/demo/bloom

# Monitor performance
./scripts/monitor-cache.sh stats
```

## 🔍 Troubleshooting

### Common Issues

1. **Redis Connection Error**
   ```bash
   # Check Redis status
   redis-cli ping
   docker ps | grep redis
   ```

2. **Port Already in Use**
   ```bash
   # Find process using port
   netstat -tulpn | grep :3000
   # Kill process
   pkill -f "node dist/web-server.js"
   ```

3. **Build Errors**
   ```bash
   # Clean and rebuild
   npm run clean
   npm install
   npm run build
   ```

4. **Permission Issues**
   ```bash
   # Make scripts executable
   chmod +x scripts/*.sh
   ```

For detailed troubleshooting, see [docs/DIAGNOSTICS.md](docs/DIAGNOSTICS.md).

## 🛡️ Production Considerations

### Security

- Configure firewall rules (port 3000)
- Use environment variables for sensitive configuration
- Enable Redis authentication if needed
- Set up SSL/TLS for production traffic

### Performance

- Configure Redis memory limits and eviction policies
- Monitor application logs and Redis metrics
- Set up log rotation for application logs
- Consider Redis clustering for high availability

### Deployment

- Use systemd service for automatic startup
- Configure nginx reverse proxy for SSL termination
- Set up monitoring and alerting
- Implement backup strategies for Redis data

## 📝 License

This project is for educational and learning purposes.

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

---

**Happy coding with Redis Bloom Filters! 🎯**
```

## 📖 Detailed Setup Process

### What the Setup Script Does

The `setup-redis-bloom.sh` script implements a **multi-tiered approach** with automatic fallbacks:

#### 🐳 **Primary Approach: Docker Redis Stack**
1. **Docker Installation** (if needed):
   - Updates package repositories
   - Installs required dependencies (`ca-certificates`, `curl`, `gnupg`, `lsb-release`)
   - Adds Docker's official GPG key and repository
   - Installs Docker Engine, CLI, and containerd
   - Adds current user to docker group
   - Starts and enables Docker service

2. **Redis Stack Deployment**:
   - Stops any existing Redis containers/services
   - Pulls `redis/redis-stack-server:latest` image
   - Runs container with ports 6379 (Redis) and 8001 (RedisInsight)
   - Enables auto-restart policy
   - Tests connectivity and module availability

#### 🔧 **Fallback Approach: Manual Compilation**
1. **System Redis Installation**:
   - Installs `redis-server` and `redis-tools` via apt
   - Starts and enables Redis service

2. **Build Environment Setup**:
   - Installs build dependencies: `git`, `build-essential`, `python3`, `cmake`
   - Prepares compilation environment

3. **RedisBloom Compilation**:
   - Clones RedisBloom from GitHub
   - Initializes and updates git submodules
   - Compiles from source using make
   - Installs compiled module to `/usr/lib/redis/modules/`

4. **Redis Configuration**:
   - Modifies `/etc/redis/redis.conf` to load RedisBloom
   - Enables module commands
   - Restarts Redis service
   - Attempts dynamic module loading if static loading fails

#### ✅ **Verification & Testing**
- Tests Redis connectivity with `ping`
- Verifies RedisBloom module is loaded
- Performs actual Bloom filter operations test
- Provides comprehensive status reporting

## 🔬 What the Application Does

The application demonstrates comprehensive Redis Bloom filter operations:

### Core Bloom Filter Operations
- **`BF.RESERVE`** - Creates a bloom filter with specified error rate (0.01) and capacity (1000)
- **`BF.ADD`** - Adds a single item to the bloom filter
- **`BF.EXISTS`** - Checks if a single item exists in the bloom filter
- **`BF.MADD`** - Adds multiple items to the bloom filter in one operation
- **`BF.MEXISTS`** - Checks if multiple items exist in the bloom filter

### Sample Data
The application uses bike model names as test data:
- `"Smoky Mountain Striker"`
- `"Rocky Mountain Racer"`
- `"Cloudy City Cruiser"`
- `"Windy City Wippet"`

### Expected Output
```
[INFO] Connecting to Redis...
[INFO] Connected to Redis successfully
[INFO] Bloom filter reserve result: "OK"
[INFO] Bloom filter add result: true
[INFO] Bloom filter exists result: true
[INFO] Bloom filter mAdd result: [true, true, true]
[INFO] Bloom filter mExists result: [true, true, true]
[INFO] Redis connection closed
```

## 🐳 Redis Stack Components

When using the Docker approach, you get access to:

### **Redis Server** (Port 6379)
- Core Redis functionality
- Bloom filter operations via RedisBloom

### **RedisBloom Module**
- Probabilistic data structures
- Bloom filters, Cuckoo filters, Count-Min sketches, Top-K

### **Additional Modules** (included in Redis Stack)
- **RedisJSON** - JSON data type support
- **RedisTimeSeries** - Time series data structures
- **RedisSearch** - Full-text search and indexing
- **RedisGraph** - Graph database capabilities

### **RedisInsight** (Port 8001)
- Web-based Redis management interface
- Visual data browser and editor
- Performance monitoring
- CLI interface

## 📋 Manual Setup Alternative

If you prefer to set up everything manually instead of using the automated script:

### Option 1: Docker Setup (Recommended)
```bash
# Install Docker (Ubuntu/Debian)
sudo apt update
sudo apt install ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# Run Redis Stack
docker run -d --name redis-stack -p 6379:6379 -p 8001:8001 redis/redis-stack-server:latest

# Test connection
redis-cli ping
redis-cli MODULE LIST
```

### Option 2: Manual Compilation
```bash
# Install Redis
sudo apt update
sudo apt install redis-server redis-tools

# Install build dependencies
sudo apt install git build-essential python3 cmake

# Clone and build RedisBloom
cd /tmp
git clone https://github.com/RedisBloom/RedisBloom.git
cd RedisBloom
git submodule update --init --recursive
make

# Install module
sudo mkdir -p /usr/lib/redis/modules
sudo cp bin/linux-x64-release/redisbloom.so /usr/lib/redis/modules/

# Configure Redis
echo "loadmodule /usr/lib/redis/modules/redisbloom.so" | sudo tee -a /etc/redis/redis.conf
echo "enable-module-command yes" | sudo tee -a /etc/redis/redis.conf

# Restart Redis
sudo systemctl restart redis-server
```

## 🔧 Development Commands

### Building and Running
```bash
# Install dependencies
npm install

# Build TypeScript to JavaScript
npm run build

# Run the compiled application
npm start

# Development mode (if nodemon is configured)
npm run dev
```

### Redis Management
```bash
# Check Redis status
redis-cli ping

# List loaded modules
redis-cli MODULE LIST

# View Redis info
redis-cli INFO

# Monitor Redis commands
redis-cli MONITOR
```

### Docker Management
```bash
# Container management
docker start redis-stack
docker stop redis-stack
docker restart redis-stack
docker logs redis-stack

# Remove container (if you want to start fresh)
docker stop redis-stack
docker rm redis-stack
```

## 🛠️ Troubleshooting

### Common Issues and Solutions

#### **Issue: Docker Permission Denied**
```bash
# Error: permission denied while trying to connect to Docker daemon
sudo usermod -aG docker $USER
newgrp docker
# Or log out and back in
```

#### **Issue: Port 6379 Already in Use**
```bash
# Check what's using the port
sudo netstat -tlnp | grep 6379

# Stop system Redis if running
sudo systemctl stop redis-server

# Or use different port for Docker
docker run -d --name redis-stack -p 6380:6379 -p 8001:8001 redis/redis-stack-server:latest
```

#### **Issue: Redis Connection Refused**
```bash
# Check if container is running
docker ps

# Check container logs
docker logs redis-stack

# Restart container
docker restart redis-stack

# Check Redis status (manual setup)
sudo systemctl status redis-server
```

#### **Issue: RedisBloom Module Not Found**
```bash
# Verify module is loaded
redis-cli MODULE LIST | grep bf

# For Docker setup - restart container
docker restart redis-stack

# For manual setup - check configuration
sudo grep -i "loadmodule" /etc/redis/redis.conf
```

#### **Issue: Build Compilation Errors**
```bash
# Install missing dependencies
sudo apt update
sudo apt install build-essential cmake python3 python3-pip git

# Clean and rebuild
cd /tmp/RedisBloom
make clean
make
```

#### **Issue: Node.js Application Errors**
```bash
# Check if Redis is accessible
redis-cli ping

# Verify bloom filter commands work
redis-cli BF.RESERVE test 0.01 100
redis-cli BF.ADD test "item1"
redis-cli BF.EXISTS test "item1"
redis-cli DEL test

# Check application logs
npm start
```

### Getting Help

#### **Check Script Logs**
The setup script provides detailed output with color-coded messages:
- 🔵 **Blue**: Information messages
- 🟢 **Green**: Success messages
- 🟡 **Yellow**: Warning messages
- 🔴 **Red**: Error messages

#### **Verify Setup**
```bash
# Quick verification commands
docker ps                           # Check if container is running
redis-cli ping                     # Test Redis connectivity
redis-cli MODULE LIST             # Verify modules are loaded
redis-cli BF.RESERVE test 0.01 10 # Test bloom filter
```

#### **Manual Diagnosis**
```bash
# System diagnostics
docker info                        # Docker status
sudo systemctl status redis-server # System Redis status
sudo journalctl -u redis-server   # Redis logs (manual setup)
docker logs redis-stack          # Container logs (Docker setup)
```

## 📁 Project Structure

```
├── src/
│   ├── index.ts              # Main application file with Bloom filter demo
│   └── types/
│       └── redis.d.ts        # Redis type definitions (if present)
├── dist/                     # Compiled JavaScript files (generated)
├── node_modules/             # Node.js dependencies (generated)
├── setup-redis-bloom.sh      # Comprehensive Redis setup script
├── package.json              # Node.js project configuration
├── tsconfig.json             # TypeScript configuration
└── README.md                 # This documentation file
```

### Key Files Explained

#### **`src/index.ts`**
- Main application demonstrating Bloom filter operations
- Includes Redis connection handling and graceful shutdown
- Uses Pino logger for structured logging
- Demonstrates all major Bloom filter commands

#### **`setup-redis-bloom.sh`**
- Comprehensive setup script with multiple fallback approaches
- Handles Docker installation and Redis Stack deployment
- Falls back to manual Redis + RedisBloom compilation
- Includes extensive error handling and validation

#### **`package.json`**
- Defines project dependencies (redis, pino, pino-pretty)
- Contains build and start scripts
- TypeScript and Node.js configuration

## 🔗 Learn More

### Redis and Bloom Filters
- [Redis Bloom Documentation](https://redis.io/docs/stack/bloom/)
- [RedisBloom Commands Reference](https://redis.io/commands/?group=bloom)
- [Bloom Filter Concept](https://en.wikipedia.org/wiki/Bloom_filter)

### Redis Stack
- [Redis Stack Overview](https://redis.io/docs/stack/)
- [RedisInsight GUI](https://redis.io/docs/stack/insight/)
- [Redis Modules](https://redis.io/modules)

### Development Resources
- [Node Redis Client](https://github.com/redis/node-redis)
- [TypeScript Documentation](https://www.typescriptlang.org/docs/)
- [Pino Logger](https://github.com/pinojs/pino)

### Docker Resources
- [Docker Installation Guide](https://docs.docker.com/get-docker/)
- [Redis Docker Images](https://hub.docker.com/_/redis)
- [Redis Stack Docker](https://hub.docker.com/r/redis/redis-stack)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Happy coding with Redis Bloom filters! 🚀**
