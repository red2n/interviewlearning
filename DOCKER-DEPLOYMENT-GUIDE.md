# 🐳 Docker Deployment Guide for Redis Bloom Filter Application

## 📋 Quick Summary

✅ **Docker Image Built Successfully**: `redis-bloom-app:latest`
✅ **Docker Compose Configuration**: Ready for deployment
✅ **Deployment Package**: `redis-bloom-app.tar` created for transfer
✅ **Target Server**: `ssh stayuser@stay-white.ad.local`

## 🚀 Deployment Options

### Option 1: Manual Deployment (Recommended)

Since SSH authentication needs to be configured, here's the manual deployment process:

#### Step 1: Transfer Files to Server
```bash
# Copy these files to stay-white.ad.local:
# - redis-bloom-app.tar (Docker image)
# - docker-compose.yml (orchestration)
# - config/ (Redis configuration)
# - .env.example (environment template)

# Example using scp (requires password or SSH key setup):
scp redis-bloom-app.tar stayuser@stay-white.ad.local:~/
scp docker-compose.yml stayuser@stay-white.ad.local:~/
scp -r config/ stayuser@stay-white.ad.local:~/
scp .env.example stayuser@stay-white.ad.local:~/
```

#### Step 2: Connect to Server and Deploy
```bash
# SSH to the server
ssh stayuser@stay-white.ad.local

# Load the Docker image
docker load -i redis-bloom-app.tar

# Create environment file
cp .env.example .env
# Edit .env as needed

# Start services
docker compose up -d

# Check status
docker compose ps
docker compose logs -f
```

### Option 2: Automated Deployment (Requires SSH Setup)

First, set up SSH key authentication:

```bash
# Generate SSH key (if you don't have one)
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"

# Copy public key to server
ssh-copy-id stayuser@stay-white.ad.local

# Then run the automated deployment
./scripts/docker-deploy.sh
```

## 🌐 Service URLs (After Deployment)

- **Application**: http://stay-white.ad.local:3000
- **Redis Insight**: http://stay-white.ad.local:8001
- **Health Check**: http://stay-white.ad.local:3000/health

## 📊 Service Management

### Check Status
```bash
docker compose ps
docker compose logs
```

### View Application Logs
```bash
docker compose logs redis-bloom-app -f
```

### View Redis Logs
```bash
docker compose logs redis-stack -f
```

### Restart Services
```bash
docker compose restart
```

### Stop Services
```bash
docker compose down
```

### Update Application
```bash
# Stop current version
docker compose down

# Load new image
docker load -i new-redis-bloom-app.tar

# Start updated version
docker compose up -d
```

## 🔧 Configuration

### Environment Variables (.env)
```bash
# Application
NODE_ENV=production
PORT=3000
LOG_LEVEL=info

# Redis
REDIS_HOST=redis-stack
REDIS_PORT=6379
REDIS_PASSWORD=""

# Bloom Filter
DEFAULT_CAPACITY=10000
DEFAULT_ERROR_RATE=0.01
```

### Custom Redis Configuration
- Configuration files are in the `config/` directory
- Redis Stack includes Redis Bloom filters by default
- RedisInsight is available for database management

## 🚦 Health Checks

The application includes health checks:
- **Application Health**: GET /health
- **Redis Health**: GET /health/redis
- **Docker Health**: Built into Docker Compose

## 📈 Monitoring

### Application Metrics
```bash
curl http://stay-white.ad.local:3000/health
```

### Redis Metrics
```bash
# Connect to Redis CLI
docker compose exec redis-stack redis-cli
# Run: INFO server
```

### Container Metrics
```bash
docker stats
```

## 🔐 Security Considerations

1. **Network Security**: Services are on isolated Docker network
2. **User Privileges**: Application runs as non-root user (nodejs:1001)
3. **Redis Security**: Consider setting Redis password in production
4. **Firewall**: Ensure appropriate ports are open (3000, 8001)

## 🐛 Troubleshooting

### Port Conflicts
If ports 3000 or 8001 are already in use:
```bash
# Check port usage
netstat -tulpn | grep :3000
netstat -tulpn | grep :8001

# Stop conflicting services or modify docker-compose.yml ports
```

### Container Issues
```bash
# View container logs
docker compose logs

# Restart specific service
docker compose restart redis-bloom-app

# Rebuild image if needed
docker compose build --no-cache
```

### Redis Connection Issues
```bash
# Test Redis connectivity
docker compose exec redis-bloom-app redis-cli -h redis-stack ping

# Check Redis configuration
docker compose exec redis-stack redis-cli CONFIG GET "*"
```

## 📦 File Structure

```
📁 Redis Bloom Filter Application
├── 🐳 redis-bloom-app.tar          # Docker image for transfer
├── 📄 docker-compose.yml           # Container orchestration
├── 📄 Dockerfile                   # Image build instructions
├── 📄 .env.example                 # Environment template
├── 📁 config/                      # Redis configuration
│   ├── docker-compose.cache.yml    # Cache configuration
│   └── redis-cache.conf            # Redis settings
├── 📁 src/                         # Application source
├── 📁 scripts/                     # Deployment scripts
└── 📁 docs/                        # Documentation
```

## ✅ Deployment Checklist

- [ ] SSH access to stay-white.ad.local configured
- [ ] Docker and Docker Compose installed on target server
- [ ] Ports 3000 and 8001 available on target server
- [ ] Files transferred to server
- [ ] Docker image loaded
- [ ] Environment variables configured
- [ ] Services started with `docker compose up -d`
- [ ] Health checks passing
- [ ] Application accessible at http://stay-white.ad.local:3000

## 🎯 Next Steps

1. **Setup SSH Authentication**: Configure SSH keys for automated deployment
2. **Monitoring**: Set up application and infrastructure monitoring
3. **Backup Strategy**: Implement Redis data backup procedures
4. **SSL/TLS**: Configure HTTPS with reverse proxy (nginx/traefik)
5. **CI/CD**: Integrate with GitHub Actions for automated deployments

---

**Created**: $(date)
**Docker Image**: redis-bloom-app:latest
**Target**: stay-white.ad.local
**Status**: Ready for deployment 🚀
