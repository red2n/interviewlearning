# Redis Bloom Filter Project

This project demonstrates Redis Bloom filter operations using Node.js and TypeScript with a comprehensive setup script that handles multiple installation approaches.

## 📋 Prerequisites

### Minimum Requirements
- **Node.js** (v14 or higher)
- **Linux/Ubuntu** system
- **sudo** privileges
- **Internet connection**

### Optional (will be auto-installed)
- **Docker** (recommended - will be installed automatically)
- **Redis** (will be installed if Docker approach fails)
- **Build tools** (installed automatically when needed)

## 🚀 Quick Start (Automated Setup)

### Step 1: Clone and Install Dependencies
```bash
# If you haven't already cloned the repository
git clone <your-repo-url>
cd learning

# Install Node.js dependencies
npm install
```

### Step 2: Run Comprehensive Setup Script
```bash
# Make the script executable (if not already)
chmod +x setup-redis-bloom.sh

# Run the comprehensive setup script
./setup-redis-bloom.sh
```

The script will automatically:
- ✅ Install Docker (if not present)
- ✅ Set up Redis Stack with RedisBloom (recommended)
- ✅ Fall back to manual Redis + RedisBloom compilation if needed
- ✅ Test all connections and functionality
- ✅ Provide detailed status and next steps

### Step 3: Build and Run Your Application
```bash
# Build the TypeScript code
npm run build

# Run the application
npm start
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
