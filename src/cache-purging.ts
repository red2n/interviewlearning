import { createClient } from 'redis';
import pino from 'pino';

const logger = pino({
    transport: {
        target: 'pino-pretty',
        options: {
            colorize: true
        }
    }
});

const client = createClient({
    url: 'redis://localhost:6379'
});

client.on('error', (err: any) => logger.error({ err }, 'Redis Client Error'));

async function demonstrateRedisCachePurging() {
    try {
        logger.info('Connecting to Redis...');
        await client.connect();
        logger.info('Connected to Redis successfully');

        // 1. TTL (Time To Live) - Auto expiration
        logger.info('=== TTL (Time To Live) Examples ===');

        // Set key with 10 seconds expiration
        await client.setEx('cache:user:123', 10, JSON.stringify({ name: 'John', age: 30 }));
        logger.info('Set cache:user:123 with 10 seconds TTL');

        // Check TTL
        const ttl = await client.ttl('cache:user:123');
        logger.info({ ttl }, 'Current TTL for cache:user:123');

        // 2. EXPIRE command - Set expiration on existing key
        await client.set('cache:session:abc', 'session-data');
        await client.expire('cache:session:abc', 30); // 30 seconds
        logger.info('Set cache:session:abc with 30 seconds expiration');

        // 3. EXPIREAT - Expire at specific timestamp
        const futureTimestamp = Math.floor(Date.now() / 1000) + 60; // 1 minute from now
        await client.set('cache:temp:xyz', 'temporary-data');
        await client.expireAt('cache:temp:xyz', futureTimestamp);
        logger.info('Set cache:temp:xyz to expire at specific timestamp');

        // 4. PEXPIRE - Expire in milliseconds
        await client.set('cache:fast:123', 'quick-data');
        await client.pExpire('cache:fast:123', 5000); // 5000ms = 5 seconds
        logger.info('Set cache:fast:123 with 5000ms TTL');

        // 5. Configure Redis for automatic memory management
        logger.info('=== Redis Memory Management Configuration ===');

        // Set maxmemory policy (requires admin privileges)
        try {
            // Get current maxmemory settings
            const maxMemory = await client.configGet('maxmemory');
            const maxMemoryPolicy = await client.configGet('maxmemory-policy');
            logger.info({ maxMemory, maxMemoryPolicy }, 'Current memory settings');

            // These require admin privileges, so they might fail
            // await client.configSet('maxmemory', '100mb');
            // await client.configSet('maxmemory-policy', 'allkeys-lru');
            logger.info('Memory policies that can be set: allkeys-lru, allkeys-lfu, volatile-lru, volatile-lfu, volatile-ttl, volatile-random, allkeys-random, noeviction');
        } catch (error) {
            logger.warn('Could not modify memory settings (requires admin privileges)');
        }

        // 6. Batch operations with TTL
        logger.info('=== Batch Operations with TTL ===');

        const pipeline = client.multi();
        pipeline.setEx('cache:batch:1', 15, 'data1');
        pipeline.setEx('cache:batch:2', 20, 'data2');
        pipeline.setEx('cache:batch:3', 25, 'data3');
        await pipeline.exec();
        logger.info('Set multiple cache entries with different TTLs');

        // 7. Check which keys will expire soon
        logger.info('=== Monitoring Expiring Keys ===');

        const keys = await client.keys('cache:*');
        for (const key of keys) {
            const keyTtl = await client.ttl(key);
            if (keyTtl > 0) {
                logger.info({ key, ttl: keyTtl }, 'Key expiration info');
            }
        }

        // 8. Manual cache cleanup patterns
        logger.info('=== Manual Cache Cleanup Patterns ===');

        // Delete keys by pattern
        const tempKeys = await client.keys('cache:temp:*');
        if (tempKeys.length > 0) {
            await client.del(tempKeys);
            logger.info({ deletedCount: tempKeys.length }, 'Deleted temporary cache keys');
        }

        // 9. Advanced: Sliding window expiration
        logger.info('=== Sliding Window Expiration ===');

        const slidingKey = 'cache:sliding:window';
        await client.set(slidingKey, 'sliding-data');
        await client.expire(slidingKey, 30);

        // Simulate accessing the key (reset expiration)
        const data = await client.get(slidingKey);
        if (data) {
            await client.expire(slidingKey, 30); // Reset TTL on access
            logger.info('Reset TTL for sliding window cache');
        }

        // 10. Bloom filter with expiration (your specific use case)
        logger.info('=== Bloom Filter Cache Management ===');

        // Create bloom filter with cleanup
        await client.bf.reserve('cache:bloom:products', 0.01, 1000);

        // Add items
        await client.bf.add('cache:bloom:products', 'product:123');
        await client.bf.add('cache:bloom:products', 'product:456');

        // Set expiration on bloom filter
        await client.expire('cache:bloom:products', 300); // 5 minutes
        logger.info('Created bloom filter with 5 minute expiration');

        // Wait a bit to see some expirations
        logger.info('Waiting 3 seconds to demonstrate TTL...');
        await new Promise(resolve => setTimeout(resolve, 3000));

        // Check TTLs again
        const finalKeys = await client.keys('cache:*');
        for (const key of finalKeys) {
            const keyTtl = await client.ttl(key);
            logger.info({ key, ttl: keyTtl }, 'Final TTL status');
        }

        await client.quit();
        logger.info('Redis connection closed');

    } catch (error) {
        logger.error({ error }, 'Error in cache purging demonstration');
        process.exit(1);
    }
}

// Function to set up Redis memory configuration (run as admin)
async function setupMemoryConfiguration() {
    const adminClient = createClient({
        url: 'redis://localhost:6379'
    });

    try {
        await adminClient.connect();

        // Configure Redis for automatic cache eviction
        await adminClient.configSet('maxmemory', '256mb');
        await adminClient.configSet('maxmemory-policy', 'allkeys-lru');

        // Optional: Configure how often Redis checks for expired keys
        await adminClient.configSet('hz', '100');

        logger.info('Redis memory configuration updated successfully');
        await adminClient.quit();
    } catch (error) {
        logger.error({ error }, 'Failed to configure Redis memory settings');
    }
}

// Function to create a cache cleanup scheduled task
function scheduleCleanupTask() {
    const cleanupInterval = setInterval(async () => {
        try {
            if (!client.isOpen) {
                await client.connect();
            }

            // Clean up expired session data
            const sessionKeys = await client.keys('cache:session:*');
            let deletedCount = 0;

            for (const key of sessionKeys) {
                const ttl = await client.ttl(key);
                if (ttl === -1) { // Key has no expiration
                    // Optionally set expiration for keys without TTL
                    await client.expire(key, 3600); // 1 hour default
                } else if (ttl === -2) { // Key doesn't exist
                    deletedCount++;
                }
            }

            if (deletedCount > 0) {
                logger.info({ deletedCount }, 'Cleanup task completed');
            }

        } catch (error) {
            logger.error({ error }, 'Error in scheduled cleanup task');
        }
    }, 60000); // Run every minute

    // Cleanup on exit
    process.on('SIGINT', () => {
        clearInterval(cleanupInterval);
        logger.info('Cleanup task stopped');
        process.exit(0);
    });

    return cleanupInterval;
}

// Export functions for use in other modules
export {
    demonstrateRedisCachePurging,
    setupMemoryConfiguration,
    scheduleCleanupTask
};

// Run demonstration if this file is executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
    demonstrateRedisCachePurging();
}
