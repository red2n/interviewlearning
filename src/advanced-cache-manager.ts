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

export class RedisCacheManager {
    private client;

    constructor(redisUrl: string = 'redis://localhost:6379') {
        this.client = createClient({
            url: redisUrl,
            socket: {
                reconnectStrategy: (retries: number) => Math.min(retries * 50, 1000)
            }
        });

        this.client.on('error', (err: any) =>
            logger.error({ err }, 'Redis Client Error')
        );
    }

    async connect(): Promise<void> {
        if (!this.client.isOpen) {
            await this.client.connect();
            logger.info('Connected to Redis');
        }
    }

    async disconnect(): Promise<void> {
        if (this.client.isOpen) {
            await this.client.quit();
            logger.info('Disconnected from Redis');
        }
    }

    // =============================================================================
    // TTL-BASED CACHE METHODS
    // =============================================================================

    /**
     * Set cache with automatic expiration
     */
    async setWithTTL(key: string, value: any, ttlSeconds: number): Promise<void> {
        await this.client.setEx(key, ttlSeconds, JSON.stringify(value));
        logger.debug({ key, ttl: ttlSeconds }, 'Cache set with TTL');
    }

    /**
     * Get cache value and optionally refresh TTL
     */
    async getWithRefresh(key: string, refreshTTL?: number): Promise<any> {
        const value = await this.client.get(key);

        if (value && refreshTTL) {
            await this.client.expire(key, refreshTTL);
            logger.debug({ key, refreshTTL }, 'Cache TTL refreshed');
        }

        return value ? JSON.parse(value) : null;
    }

    /**
     * Sliding window cache - extends TTL on each access
     */
    async setSlidingCache(key: string, value: any, ttlSeconds: number): Promise<void> {
        await this.client.setEx(key, ttlSeconds, JSON.stringify(value));
    }

    async getSlidingCache(key: string, ttlSeconds: number): Promise<any> {
        const value = await this.client.get(key);

        if (value) {
            // Reset TTL on access (sliding window)
            await this.client.expire(key, ttlSeconds);
            return JSON.parse(value);
        }

        return null;
    }

    // =============================================================================
    // BLOOM FILTER CACHE METHODS
    // =============================================================================

    /**
     * Create bloom filter with expiration
     */
    async createBloomCache(name: string, errorRate: number, capacity: number, ttlSeconds: number): Promise<void> {
        await this.client.bf.reserve(name, errorRate, capacity);
        await this.client.expire(name, ttlSeconds);
        logger.info({ name, errorRate, capacity, ttl: ttlSeconds }, 'Bloom filter cache created');
    }

    /**
     * Add item to bloom filter and refresh TTL
     */
    async addToBloomCache(name: string, item: string, ttlSeconds?: number): Promise<boolean> {
        const result = await this.client.bf.add(name, item);

        if (ttlSeconds) {
            await this.client.expire(name, ttlSeconds);
        }

        return result;
    }

    // =============================================================================
    // BATCH OPERATIONS WITH TTL
    // =============================================================================

    /**
     * Set multiple cache entries with different TTLs
     */
    async setBatch(entries: Array<{key: string, value: any, ttl: number}>): Promise<void> {
        const pipeline = this.client.multi();

        for (const entry of entries) {
            pipeline.setEx(entry.key, entry.ttl, JSON.stringify(entry.value));
        }

        await pipeline.exec();
        logger.info({ count: entries.length }, 'Batch cache set completed');
    }

    // =============================================================================
    // CLEANUP AND MAINTENANCE
    // =============================================================================

    /**
     * Manual cleanup of expired or pattern-matched keys
     */
    async cleanup(pattern: string): Promise<number> {
        const keys = await this.client.keys(pattern);
        let deletedCount = 0;

        for (const key of keys) {
            const ttl = await this.client.ttl(key);

            // Delete keys with no TTL (never expire) that match cleanup pattern
            if (ttl === -1 && pattern.includes('temp')) {
                await this.client.del(key);
                deletedCount++;
            }
        }

        logger.info({ pattern, deletedCount }, 'Manual cleanup completed');
        return deletedCount;
    }

    /**
     * Get cache statistics
     */
    async getCacheStats(): Promise<any> {
        const info = await this.client.info('memory');
        const keyspace = await this.client.info('keyspace');
        const stats = await this.client.info('stats');

        return {
            memory: this.parseInfo(info),
            keyspace: this.parseInfo(keyspace),
            stats: this.parseInfo(stats)
        };
    }

    /**
     * Monitor keys about to expire
     */
    async getExpiringKeys(pattern: string, thresholdSeconds: number = 60): Promise<Array<{key: string, ttl: number}>> {
        const keys = await this.client.keys(pattern);
        const expiringKeys = [];

        for (const key of keys) {
            const ttl = await this.client.ttl(key);
            if (ttl > 0 && ttl <= thresholdSeconds) {
                expiringKeys.push({ key, ttl });
            }
        }

        return expiringKeys;
    }

    // =============================================================================
    // AUTOMATIC PURGING STRATEGIES
    // =============================================================================

    /**
     * Start automatic cleanup scheduler
     */
    startAutoCleanup(intervalMs: number = 60000): NodeJS.Timeout {
        const interval = setInterval(async () => {
            try {
                // Clean up temporary caches
                await this.cleanup('cache:temp:*');

                // Clean up session data older than 1 hour without TTL
                const sessionKeys = await this.client.keys('cache:session:*');
                for (const key of sessionKeys) {
                    const ttl = await this.client.ttl(key);
                    if (ttl === -1) {
                        // Set default expiration for sessions without TTL
                        await this.client.expire(key, 3600); // 1 hour
                    }
                }

                // Log cache statistics
                const stats = await this.getCacheStats();
                logger.debug({ stats }, 'Auto cleanup cycle completed');

            } catch (error) {
                logger.error({ error }, 'Error in auto cleanup cycle');
            }
        }, intervalMs);

        logger.info({ intervalMs }, 'Auto cleanup scheduler started');
        return interval;
    }

    /**
     * Configure Redis memory management
     */
    async configureMemoryManagement(maxMemory: string, policy: string = 'allkeys-lru'): Promise<void> {
        try {
            await this.client.configSet('maxmemory', maxMemory);
            await this.client.configSet('maxmemory-policy', policy);
            await this.client.configSet('hz', '100'); // Increase key expiration frequency

            logger.info({ maxMemory, policy }, 'Redis memory management configured');
        } catch (error) {
            logger.error({ error }, 'Failed to configure Redis memory management');
            throw error;
        }
    }

    // =============================================================================
    // UTILITY METHODS
    // =============================================================================

    private parseInfo(infoString: string): Record<string, string> {
        const result: Record<string, string> = {};
        const lines = infoString.split('\r\n');

        for (const line of lines) {
            if (line && !line.startsWith('#')) {
                const [key, value] = line.split(':');
                if (key && value) {
                    result[key] = value;
                }
            }
        }

        return result;
    }
}

// =============================================================================
// USAGE EXAMPLES
// =============================================================================

export async function demonstrateAdvancedCaching(): Promise<void> {
    const cache = new RedisCacheManager();
    await cache.connect();

    try {
        // Example 1: User session with auto-refresh
        await cache.setWithTTL('session:user123', { userId: 123, role: 'admin' }, 1800); // 30 minutes

        // Access session and refresh TTL
        const session = await cache.getWithRefresh('session:user123', 1800);
        logger.info({ session }, 'Session retrieved and refreshed');

        // Example 2: Sliding window cache for frequently accessed data
        await cache.setSlidingCache('hot:data:product456', { name: 'Product', price: 99.99 }, 300);
        const product = await cache.getSlidingCache('hot:data:product456', 300); // Extends TTL
        logger.info({ product }, 'Product data with sliding window');

        // Example 3: Bloom filter cache for recent searches
        await cache.createBloomCache('searches:recent', 0.01, 10000, 3600); // 1 hour
        await cache.addToBloomCache('searches:recent', 'redis tutorial');
        await cache.addToBloomCache('searches:recent', 'cache management');

        // Example 4: Batch cache operations
        const batchData = [
            { key: 'cache:api:endpoint1', value: { data: 'response1' }, ttl: 600 },
            { key: 'cache:api:endpoint2', value: { data: 'response2' }, ttl: 900 },
            { key: 'cache:api:endpoint3', value: { data: 'response3' }, ttl: 1200 }
        ];
        await cache.setBatch(batchData);

        // Example 5: Configure memory management
        await cache.configureMemoryManagement('256mb', 'allkeys-lru');

        // Example 6: Start auto cleanup
        const cleanupInterval = cache.startAutoCleanup(30000); // Every 30 seconds

        // Example 7: Monitor expiring keys
        setTimeout(async () => {
            const expiring = await cache.getExpiringKeys('cache:*', 120);
            logger.info({ expiring }, 'Keys expiring in next 2 minutes');
        }, 5000);

        // Cleanup after demonstration
        setTimeout(async () => {
            clearInterval(cleanupInterval);
            await cache.disconnect();
        }, 10000);

    } catch (error) {
        logger.error({ error }, 'Error in advanced caching demonstration');
        await cache.disconnect();
    }
}

// Run demonstration if file is executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
    demonstrateAdvancedCaching();
}
