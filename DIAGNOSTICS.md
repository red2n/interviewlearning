# Redis Bloom Filter Diagnostics Guide

This document provides comprehensive diagnostics and troubleshooting steps for the Redis Bloom Filter project, based on real-world setup and debugging scenarios.

## 🔍 Common Issues and Diagnostics

### Issue 1: Redis Connection Refused (ECONNREFUSED)

#### **Symptoms:**
```
ERROR: connect ECONNREFUSED 127.0.0.1:6379
Redis Client Error: Connection refused
```

#### **Root Cause:**
Redis server is not running or not accessible on port 6379.

#### **Diagnostic Steps:**
```bash
# Check if Redis is running
redis-cli ping
# Expected: PONG

# Check what's using port 6379
sudo netstat -tlnp | grep 6379

# Check if Docker containers are running
docker ps | grep redis

# Check system Redis service status
sudo systemctl status redis-server
```

#### **Solutions:**
1. **Start Redis Stack Container:**
   ```bash
   docker start redis-stack
   # Or if container doesn't exist:
   ./setup-redis-bloom.sh
   ```

2. **Start System Redis:**
   ```bash
   sudo systemctl start redis-server
   ```

3. **Install and Setup Redis:**
   ```bash
   # Use our comprehensive setup script
   ./setup-redis-bloom.sh
   ```

---

### Issue 2: RedisBloom Module Not Found

#### **Symptoms:**
```
TypeError: Cannot read property 'reserve' of undefined
client.bf.reserve is not a function
Module not found: bf
```

#### **Root Cause:**
RedisBloom module is not loaded in the Redis instance.

#### **Diagnostic Steps:**
```bash
# Check loaded modules
redis-cli MODULE LIST

# Look specifically for RedisBloom
redis-cli MODULE LIST | grep bf
# Expected output: name bf

# Test bloom filter command directly
redis-cli BF.RESERVE test 0.01 100
# Expected: OK (not ERR unknown command)
```

#### **Solutions:**
1. **Use Redis Stack (Recommended):**
   ```bash
   # Stop current Redis and use Redis Stack
   sudo systemctl stop redis-server
   docker run -d --name redis-stack -p 6379:6379 redis/redis-stack-server:latest
   ```

2. **Load Module Dynamically:**
   ```bash
   # If you have the compiled module
   redis-cli MODULE LOAD /usr/lib/redis/modules/redisbloom.so
   ```

3. **Compile and Install RedisBloom:**
   ```bash
   # Use our setup script's manual approach
   ./setup-redis-bloom.sh
   ```

---

### Issue 3: Application Runs but Gets Empty Error

#### **Symptoms:**
```
[INFO] Connected to Redis successfully
[ERROR] Error in Redis operations
    error: {}
```

#### **Root Cause:**
Redis client connects successfully but Bloom filter operations fail silently due to existing filters or permission issues.

#### **Diagnostic Steps:**
```bash
# Test Redis connectivity
redis-cli ping

# Check if Bloom filter already exists
redis-cli EXISTS bikes:models
# If returns 1, the filter exists

# Test Bloom filter operations manually
redis-cli BF.RESERVE test:diagnostic 0.01 100
redis-cli BF.ADD test:diagnostic "test-item"
redis-cli BF.EXISTS test:diagnostic "test-item"

# Clean up test
redis-cli DEL test:diagnostic
```

#### **Solutions:**
1. **Clean Existing Filters:**
   ```bash
   # Remove existing bloom filters
   redis-cli DEL bikes:models
   # Then run the application again
   npm start
   ```

2. **Check for Multiple Redis Instances:**
   ```bash
   # Stop other Redis containers that might conflict
   docker ps | grep redis
   docker stop insights_prod_setup-redis-queue-1 insights_prod_setup-redis-cache-1
   ```

---

### Issue 4: Docker Permission Denied

#### **Symptoms:**
```
permission denied while trying to connect to Docker daemon
Got permission denied while trying to connect to the Docker daemon socket
```

#### **Root Cause:**
User is not in the docker group or Docker service is not running.

#### **Diagnostic Steps:**
```bash
# Check if user is in docker group
groups $USER | grep docker

# Check Docker service status
sudo systemctl status docker

# Test Docker access
docker info
```

#### **Solutions:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply group changes without logout
newgrp docker

# Start Docker service if needed
sudo systemctl start docker
sudo systemctl enable docker

# Test Docker access
docker run hello-world
```

---

### Issue 5: Port Conflicts

#### **Symptoms:**
```
Port 6379 is already in use
bind: address already in use
```

#### **Root Cause:**
Multiple Redis instances or other services using port 6379.

#### **Diagnostic Steps:**
```bash
# Check what's using port 6379
sudo netstat -tlnp | grep 6379
sudo lsof -i :6379

# List all Redis processes
ps aux | grep redis

# Check Docker containers on port 6379
docker ps --filter "publish=6379"
```

#### **Solutions:**
1. **Stop Conflicting Services:**
   ```bash
   # Stop system Redis
   sudo systemctl stop redis-server

   # Stop conflicting Docker containers
   docker stop $(docker ps -q --filter "publish=6379")
   ```

2. **Use Different Port:**
   ```bash
   # Run Redis Stack on different port
   docker run -d --name redis-stack -p 6380:6379 redis/redis-stack-server:latest

   # Update application config
   # Change url: 'redis://localhost:6380' in src/index.ts
   ```

---

### Issue 6: Module Compilation Failures

#### **Symptoms:**
```
make: *** No rule to make target '/rules'. Stop.
CMake not found
python3: command not found
```

#### **Root Cause:**
Missing build dependencies for compiling RedisBloom from source.

#### **Diagnostic Steps:**
```bash
# Check required tools
which git
which make
which cmake
which python3
which gcc

# Check if repositories are accessible
sudo apt update
```

#### **Solutions:**
```bash
# Install all required dependencies
sudo apt update
sudo apt install -y git build-essential python3 python3-pip cmake

# Initialize submodules if cloning manually
cd /tmp/RedisBloom
git submodule update --init --recursive

# Use our automated script instead
./setup-redis-bloom.sh
```

---

## 🧪 Verification Commands

### Quick Health Check
```bash
# 1. Check Redis connectivity
redis-cli ping
# Expected: PONG

# 2. Verify RedisBloom module
redis-cli MODULE LIST | grep bf
# Expected: name bf

# 3. Test Bloom filter operations
redis-cli BF.RESERVE health:check 0.01 100
redis-cli BF.ADD health:check "test"
redis-cli BF.EXISTS health:check "test"
redis-cli DEL health:check
# Expected: OK, 1, 1, 1

# 4. Run application
npm start
# Expected: Successful bloom filter operations
```

### Detailed System Check
```bash
# Check Docker
docker --version
docker info
docker ps | grep redis

# Check Redis Stack specifically
docker exec redis-stack redis-cli ping
docker exec redis-stack redis-cli MODULE LIST

# Check system resources
free -h
df -h
docker system df

# Check network connectivity
netstat -tlnp | grep 6379
curl -I localhost:6379 2>/dev/null || echo "Port not responding to HTTP"
```

### Application Debugging
```bash
# Build and check compiled output
npm run build
ls -la dist/

# Check dependencies
npm list redis
npm list pino

# Run with verbose output
DEBUG=* npm start

# Test specific Redis client features
node -e "
import('redis').then(async ({ createClient }) => {
  const client = createClient({ url: 'redis://localhost:6379' });
  await client.connect();
  console.log('Client BF methods:', Object.keys(client.bf || {}));
  await client.quit();
});
"
```

---

## 📊 Environment Validation

### System Requirements Check
```bash
# Operating System
lsb_release -a
uname -a

# Node.js version
node --version
npm --version

# Memory and disk space
free -h
df -h /

# Network connectivity
ping -c 1 google.com
```

### Redis Environment
```bash
# Redis version and config
redis-cli INFO server
redis-cli CONFIG GET save
redis-cli CONFIG GET dir

# Module information
redis-cli MODULE LIST
redis-cli INFO modules

# Performance metrics
redis-cli INFO stats
redis-cli INFO memory
```

---

## 🔧 Recovery Procedures

### Complete Reset
```bash
# Stop all Redis services
sudo systemctl stop redis-server
docker stop $(docker ps -q --filter ancestor=redis)

# Clean up containers
docker rm redis-stack
docker system prune -f

# Reset and restart
./setup-redis-bloom.sh
```

### Application Reset
```bash
# Clean build artifacts
npm run clean
rm -rf node_modules package-lock.json

# Reinstall dependencies
npm install

# Rebuild application
npm run build
npm start
```

### Redis Data Reset
```bash
# Flush all Redis data
redis-cli FLUSHALL

# Or remove specific bloom filters
redis-cli DEL bikes:models

# Restart application
npm start
```

---

## 📝 Logging and Monitoring

### Application Logs
```bash
# Run with detailed logging
NODE_ENV=development npm start

# Save logs to file
npm start 2>&1 | tee app.log

# Monitor real-time logs
tail -f app.log
```

### Redis Logs
```bash
# Docker container logs
docker logs redis-stack
docker logs -f redis-stack  # Follow mode

# System Redis logs
sudo journalctl -u redis-server
sudo journalctl -u redis-server -f  # Follow mode

# Redis slow query log
redis-cli SLOWLOG GET 10
```

### System Monitoring
```bash
# Monitor Docker container resources
docker stats redis-stack

# Monitor system resources
htop
iotop  # Disk I/O
nethogs  # Network usage

# Check for memory leaks
ps aux | grep redis
cat /proc/$(pgrep redis-server)/status
```

---

## 🆘 Emergency Procedures

### If Everything Fails
1. **Complete System Reset:**
   ```bash
   # Stop everything
   docker stop $(docker ps -q)
   sudo systemctl stop redis-server

   # Clean Docker
   docker system prune -a -f

   # Reinstall Redis Stack
   docker pull redis/redis-stack-server:latest
   ./setup-redis-bloom.sh
   ```

2. **Alternative: Use System Redis with Manual Module:**
   ```bash
   # Install system Redis
   sudo apt install redis-server

   # Compile RedisBloom manually
   cd /tmp
   git clone https://github.com/RedisBloom/RedisBloom.git
   cd RedisBloom
   git submodule update --init --recursive
   make

   # Configure and restart
   sudo cp bin/linux-x64-release/redisbloom.so /usr/lib/redis/modules/
   echo "loadmodule /usr/lib/redis/modules/redisbloom.so" | sudo tee -a /etc/redis/redis.conf
   sudo systemctl restart redis-server
   ```

3. **Contact Support:**
   - Check GitHub issues: https://github.com/RedisBloom/RedisBloom/issues
   - Redis community: https://redis.io/community
   - Stack Overflow with tags: `redis` `redisbloom` `node.js`

---

## ✅ Success Indicators

When everything is working correctly, you should see:

### Application Output
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

### System Status
```bash
# Redis connectivity
$ redis-cli ping
PONG

# RedisBloom module loaded
$ redis-cli MODULE LIST | grep bf
bf

# Container running
$ docker ps | grep redis-stack
09fd141323cb   redis/redis-stack-server:latest   Up 10 minutes   0.0.0.0:6379->6379/tcp

# Application exit code
$ echo $?
0
```

---

**This diagnostics guide covers the most common issues encountered during setup and operation of the Redis Bloom Filter application. Keep this document handy for quick troubleshooting reference.**
