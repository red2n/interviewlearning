# Server Deployment Guide

## Quick Deployment

Run the automated deployment script:

```bash
./scripts/server-setup-deploy.sh
```

This will:
1. Install Node.js, Docker, and Redis CLI on the server
2. Deploy the application files
3. Set up Redis Stack with Docker
4. Install dependencies
5. Test the setup

## Manual Steps After Deployment

### 1. Connect to Server
```bash
ssh stayuser@stay-white.ad.local
cd redis-bloom-app
```

### 2. Start Application
```bash
# Foreground (for testing)
PORT=3000 node dist/web-server.js

# Background (for production)
nohup PORT=3000 node dist/web-server.js > app.log 2>&1 &
```

### 3. Test from Your Machine
```bash
# Health check
curl http://stay-white.ad.local:3000/health

# Demo bloom filter
curl -X POST http://stay-white.ad.local:3000/api/demo/bloom

# Web interface
open http://stay-white.ad.local:3000
```

## Server Commands

### Check Redis Status
```bash
redis-cli ping
docker ps | grep redis
```

### Monitor Application
```bash
# View logs
tail -f app.log

# Monitor cache
./scripts/monitor-cache.sh stats
./scripts/monitor-cache.sh monitor 60

# Process status
ps aux | grep node
```

### Firewall Configuration
```bash
# Allow application port
sudo ufw allow 3000

# Check firewall status
sudo ufw status
```

## API Endpoints

Once deployed, these endpoints will be available:

- **GET** `http://stay-white.ad.local:3000/` - Web interface
- **GET** `http://stay-white.ad.local:3000/health` - Health check
- **POST** `http://stay-white.ad.local:3000/api/demo/bloom` - Demo
- **POST** `http://stay-white.ad.local:3000/api/bloom/create` - Create bloom filter
- **POST** `http://stay-white.ad.local:3000/api/bloom/:name/add` - Add items
- **POST** `http://stay-white.ad.local:3000/api/bloom/:name/check` - Check items
- **GET** `http://stay-white.ad.local:3000/api/cache/stats` - Cache stats

## Troubleshooting

### If Node.js installation fails:
```bash
# Alternative installation
sudo apt update
sudo apt install nodejs npm
```

### If Docker installation fails:
```bash
# Manual Redis installation
sudo apt install redis-server
sudo systemctl start redis-server
sudo systemctl enable redis-server
```

### If application won't start:
```bash
# Check Redis connection
redis-cli ping

# Check logs
cat app.log

# Check port availability
netstat -tulpn | grep :3000
```

### If you can't access from your machine:
1. Check firewall: `sudo ufw status`
2. Check if app is running: `ps aux | grep node`
3. Check network connectivity: `ping stay-white.ad.local`
4. Verify port is open: `telnet stay-white.ad.local 3000`
