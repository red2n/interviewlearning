# Redis Cache Auto-Purging Guide

This guide demonstrates various Redis cache auto-purging strategies and implementations for efficient memory management.

## Overview

Redis provides multiple mechanisms for automatic cache purging:

1. **TTL (Time To Live)** - Keys expire after a specified time
2. **Memory Policies** - Eviction strategies when memory limits are reached
3. **Manual Cleanup** - Scheduled removal of specific key patterns
4. **Bloom Filter Expiration** - TTL for probabilistic data structures

## Implementation Files

### Core Files

- `src/advanced-cache-manager.ts` - Comprehensive cache management class
- `src/cache-purging.ts` - Basic TTL and expiration examples
- `monitor-cache.sh` - Real-time monitoring and testing script
- `redis-cache.conf` - Redis server configuration
- `docker-compose.cache.yml` - Docker setup with cache optimization

## Quick Start

### 1. Setup Redis with Cache Configuration

```bash
# Start Redis with memory management
docker-compose -f docker-compose.cache.yml up -d

# Or configure an existing Redis instance
./monitor-cache.sh configure 128mb allkeys-lru
```

### 2. Create Demo Data

```bash
# Create test cache entries with different TTLs
./monitor-cache.sh demo
```

### 3. Monitor Cache Behavior

```bash
# View current cache statistics
./monitor-cache.sh stats

# Real-time monitoring for 2 minutes
./monitor-cache.sh monitor 120

# Run full auto-purging test
./monitor-cache.sh test
```

### 4. Run Advanced Cache Manager

```bash
# Compile TypeScript
npm run build

# Run comprehensive cache demonstration
node dist/advanced-cache-manager.js
```

## Auto-Purging Strategies

### 1. TTL-Based Expiration

**Automatic expiration** after specified time:

```typescript
// Set cache with 30-minute TTL
await cache.setWithTTL('session:user123', userData, 1800);

// Sliding window - extends TTL on each access
const data = await cache.getSlidingCache('hot:data', 300);
```

**Key Benefits:**
- Predictable expiration
- No manual intervention required
- Memory efficient for time-sensitive data

### 2. Memory-Based Eviction

**Redis eviction policies** when memory limit is reached:

```bash
# Configure memory limit and eviction policy
redis-cli config set maxmemory 256mb
redis-cli config set maxmemory-policy allkeys-lru
```

**Available Policies:**
- `allkeys-lru` - Remove least recently used keys
- `volatile-lru` - Remove LRU keys with TTL only
- `allkeys-lfu` - Remove least frequently used keys
- `volatile-ttl` - Remove keys with shortest TTL first

### 3. Pattern-Based Cleanup

**Manual cleanup** of specific key patterns:

```typescript
// Clean up temporary caches
await cache.cleanup('cache:temp:*');

// Scheduled cleanup every minute
const interval = cache.startAutoCleanup(60000);
```

### 4. Bloom Filter Expiration

**TTL for probabilistic data structures:**

```typescript
// Create bloom filter with 1-hour expiration
await cache.createBloomCache('searches:recent', 0.01, 10000, 3600);
```

## Configuration Examples

### Memory Management Configuration

```bash
# Set memory limit to 128MB
maxmemory 128mb

# Use LRU eviction for all keys
maxmemory-policy allkeys-lru

# Increase expiration frequency
hz 100

# Sample 5 keys for eviction
maxmemory-samples 5
```

### TTL Strategies

```typescript
// User sessions - 30 minutes with refresh
await cache.setWithTTL('session:user123', userData, 1800);
await cache.getWithRefresh('session:user123', 1800);

// API responses - 10 minutes fixed
await cache.setWithTTL('api:endpoint1', response, 600);

// Hot data - sliding window
await cache.setSlidingCache('hot:product123', productData, 300);
```

## Monitoring and Diagnostics

### Real-Time Monitoring

```bash
# Monitor cache for 5 minutes, update every 2 seconds
./monitor-cache.sh monitor 300 2
```

### Cache Statistics

```bash
# Show memory usage and key statistics
./monitor-cache.sh stats
```

### Expiration Tracking

```typescript
// Find keys expiring in next 2 minutes
const expiring = await cache.getExpiringKeys('cache:*', 120);
console.log('Expiring soon:', expiring);
```

## Best Practices

### 1. Choose Appropriate TTL Values

```typescript
// Short-lived data (API responses)
await cache.setWithTTL('api:data', response, 300); // 5 minutes

// Medium-lived data (user sessions)
await cache.setWithTTL('session:data', session, 1800); // 30 minutes

// Long-lived data (configuration)
await cache.setWithTTL('config:data', config, 86400); // 24 hours
```

### 2. Use Sliding Windows for Hot Data

```typescript
// Extends TTL on each access
const hotData = await cache.getSlidingCache('hot:data', 600);
```

### 3. Implement Cleanup Schedules

```typescript
// Run cleanup every hour
const cleanupInterval = cache.startAutoCleanup(3600000);

// Custom cleanup logic
setInterval(async () => {
    await cache.cleanup('temp:*');
    await cache.cleanup('cache:old:*');
}, 300000); // Every 5 minutes
```

### 4. Monitor Memory Usage

```typescript
// Check cache statistics regularly
const stats = await cache.getCacheStats();
console.log('Memory usage:', stats.memory.used_memory_human);
```

### 5. Use Batch Operations

```typescript
// Set multiple keys with different TTLs efficiently
await cache.setBatch([
    { key: 'key1', value: data1, ttl: 300 },
    { key: 'key2', value: data2, ttl: 600 },
    { key: 'key3', value: data3, ttl: 900 }
]);
```

## Testing Auto-Purging

### 1. Verify TTL Expiration

```bash
# Create test data and watch it expire
./monitor-cache.sh demo
./monitor-cache.sh test
```

### 2. Test Memory Policies

```bash
# Set low memory limit to trigger eviction
./monitor-cache.sh configure 16mb allkeys-lru

# Fill cache and observe eviction
node -e "
const redis = require('redis');
const client = redis.createClient();
client.connect().then(async () => {
    for(let i = 0; i < 1000; i++) {
        await client.set(\`test:\${i}\`, 'x'.repeat(1000));
    }
    await client.quit();
});
"
```

### 3. Monitor Real-Time Behavior

```bash
# Watch cache behavior during load
./monitor-cache.sh monitor 60 1
```

## Troubleshooting

### Common Issues

1. **Keys not expiring**: Check if TTL is set correctly
   ```bash
   redis-cli ttl keyname
   ```

2. **Memory growing continuously**: Verify eviction policy
   ```bash
   redis-cli config get maxmemory-policy
   ```

3. **Slow cleanup**: Increase Hz setting
   ```bash
   redis-cli config set hz 100
   ```

### Debug Commands

```bash
# Check memory usage
redis-cli info memory

# List all keys with TTL
redis-cli eval "
local keys = redis.call('keys', '*')
for i=1,#keys do
    local ttl = redis.call('ttl', keys[i])
    print(keys[i] .. ' TTL: ' .. ttl)
end
" 0

# Force memory cleanup
redis-cli memory purge
```

## Integration Examples

### Express.js Middleware

```typescript
import { RedisCacheManager } from './src/advanced-cache-manager';

const cache = new RedisCacheManager();

app.use(async (req, res, next) => {
    const cacheKey = `api:${req.path}`;
    const cached = await cache.getWithRefresh(cacheKey, 300);

    if (cached) {
        return res.json(cached);
    }

    next();
});
```

### Background Job Processing

```typescript
// Clean up expired job data
setInterval(async () => {
    await cache.cleanup('job:completed:*');
    await cache.cleanup('job:failed:*');
}, 3600000); // Every hour
```

### Session Management

```typescript
// Auto-expiring user sessions
class SessionManager {
    async createSession(userId: string, data: any): Promise<string> {
        const sessionId = generateId();
        await cache.setWithTTL(`session:${sessionId}`, {
            userId,
            ...data,
            createdAt: new Date()
        }, 1800); // 30 minutes
        return sessionId;
    }

    async refreshSession(sessionId: string): Promise<any> {
        return cache.getWithRefresh(`session:${sessionId}`, 1800);
    }
}
```

## Performance Considerations

### Memory Efficiency

- Use appropriate data structures (Hash vs String)
- Set reasonable TTL values
- Implement cleanup schedules
- Monitor memory usage regularly

### Network Efficiency

- Use batch operations when possible
- Implement connection pooling
- Use pipeline for multiple commands
- Consider compression for large values

### Monitoring

- Track key expiration rates
- Monitor memory usage trends
- Alert on unusual patterns
- Log cleanup operations

## Conclusion

Redis auto-purging ensures efficient memory usage through:

1. **TTL-based expiration** for time-sensitive data
2. **Memory policies** for automatic eviction
3. **Pattern-based cleanup** for specific data types
4. **Monitoring tools** for ongoing optimization

The provided implementation offers a comprehensive solution for Redis cache management with multiple purging strategies and real-time monitoring capabilities.
