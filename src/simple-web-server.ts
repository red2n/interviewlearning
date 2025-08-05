import express from 'express';
import { createClient } from 'redis';
import pino from 'pino';

const app = express();
const port = process.env.PORT ? parseInt(process.env.PORT) : 3000;

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

// Helper function for error handling
function getErrorMessage(error: unknown): string {
    if (error instanceof Error) {
        return error.message;
    }
    return String(error);
}

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
        const errorMessage = getErrorMessage(error);
        res.status(500).json({
            status: 'unhealthy',
            error: errorMessage,
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

        await redisClient.bf.reserve(name, errorRate, capacity);

        if (ttl) {
            await redisClient.expire(name, ttl);
        }

        logger.info({ name, errorRate, capacity, ttl }, 'Bloom filter created');
        res.json({ success: true, name, errorRate, capacity, ttl });
    } catch (error) {
        const errorMessage = getErrorMessage(error);
        logger.error({ error: errorMessage }, 'Error creating Bloom filter');
        res.status(500).json({ error: errorMessage });
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

        if (ttl && typeof ttl === 'number') {
            await redisClient.expire(name, ttl);
        }

        logger.info({ name, items, results }, 'Items added to Bloom filter');
        res.json({ success: true, results });
    } catch (error) {
        const errorMessage = getErrorMessage(error);
        logger.error({ error: errorMessage }, 'Error adding to Bloom filter');
        res.status(500).json({ error: errorMessage });
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
        const errorMessage = getErrorMessage(error);
        logger.error({ error: errorMessage }, 'Error checking Bloom filter');
        res.status(500).json({ error: errorMessage });
    }
});

// Cache management endpoints
app.get('/api/cache/stats', async (req, res) => {
    try {
        const info = await redisClient.info('memory');
        const keyspace = await redisClient.info('keyspace');

        res.json({ success: true, stats: { info, keyspace } });
    } catch (error) {
        const errorMessage = getErrorMessage(error);
        logger.error({ error: errorMessage }, 'Error getting cache stats');
        res.status(500).json({ error: errorMessage });
    }
});

app.post('/api/cache/set', async (req, res) => {
    try {
        const { key, value, ttl } = req.body;

        if (!key || value === undefined) {
            return res.status(400).json({ error: 'Key and value are required' });
        }

        const valueStr = JSON.stringify(value);

        if (ttl && typeof ttl === 'number') {
            await redisClient.setEx(key, ttl, valueStr);
        } else {
            await redisClient.set(key, valueStr);
        }

        logger.info({ key, ttl }, 'Cache entry set');
        res.json({ success: true });
    } catch (error) {
        const errorMessage = getErrorMessage(error);
        logger.error({ error: errorMessage }, 'Error setting cache');
        res.status(500).json({ error: errorMessage });
    }
});

app.get('/api/cache/:key', async (req, res) => {
    try {
        const { key } = req.params;
        const { refreshTTL } = req.query;

        const rawValue = await redisClient.get(key);
        let value = rawValue ? JSON.parse(rawValue) : null;

        // Refresh TTL if requested
        if (refreshTTL && typeof refreshTTL === 'string' && value) {
            const ttl = parseInt(refreshTTL);
            if (!isNaN(ttl)) {
                await redisClient.expire(key, ttl);
            }
        }

        res.json({ success: true, value });
    } catch (error) {
        const errorMessage = getErrorMessage(error);
        logger.error({ error: errorMessage }, 'Error getting cache');
        res.status(500).json({ error: errorMessage });
    }
});

app.delete('/api/cache/:pattern', async (req, res) => {
    try {
        const { pattern } = req.params;

        const keys = await redisClient.keys(pattern);
        let deletedCount = 0;

        if (keys.length > 0) {
            deletedCount = await redisClient.del(keys);
        }

        logger.info({ pattern, deletedCount }, 'Cache cleanup performed');
        res.json({ success: true, deletedCount });
    } catch (error) {
        const errorMessage = getErrorMessage(error);
        logger.error({ error: errorMessage }, 'Error cleaning cache');
        res.status(500).json({ error: errorMessage });
    }
});

// Demo endpoints
app.post('/api/demo/bloom', async (req, res) => {
    try {
        // Create demo bloom filter
        const filterName = 'demo:search';
        await redisClient.bf.reserve(filterName, 0.01, 1000);
        await redisClient.expire(filterName, 3600); // 1 hour TTL

        // Add demo data
        const searchTerms = ['redis', 'bloom filter', 'cache', 'nosql', 'database'];
        await redisClient.bf.mAdd(filterName, searchTerms);

        // Test some checks
        const checkTerms = ['redis', 'mysql', 'cache', 'unknown'];
        const results = await redisClient.bf.mExists(filterName, checkTerms);

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
        const errorMessage = getErrorMessage(error);
        logger.error({ error: errorMessage }, 'Error creating demo');
        res.status(500).json({ error: errorMessage });
    }
});

// Static file serving for documentation
app.get('/', (req, res) => {
    res.send(`
        <html>
            <head>
                <title>Redis Bloom Filter Application</title>
                <style>
                    body { font-family: Arial, sans-serif; margin: 40px; }
                    pre { background: #f5f5f5; padding: 15px; border-radius: 5px; overflow-x: auto; }
                    li { margin: 5px 0; }
                </style>
            </head>
            <body>
                <h1>Redis Bloom Filter Application</h1>
                <p>A comprehensive Redis-based application with Bloom filters and cache management.</p>

                <h2>Available Endpoints:</h2>
                <ul>
                    <li><strong>GET /health</strong> - Health check and status</li>
                    <li><strong>POST /api/bloom/create</strong> - Create a new bloom filter</li>
                    <li><strong>POST /api/bloom/:name/add</strong> - Add items to bloom filter</li>
                    <li><strong>POST /api/bloom/:name/check</strong> - Check items in bloom filter</li>
                    <li><strong>GET /api/cache/stats</strong> - Get Redis cache statistics</li>
                    <li><strong>POST /api/cache/set</strong> - Set cache entry with optional TTL</li>
                    <li><strong>GET /api/cache/:key</strong> - Get cache entry</li>
                    <li><strong>DELETE /api/cache/:pattern</strong> - Clean cache by pattern</li>
                    <li><strong>POST /api/demo/bloom</strong> - Create demo bloom filter</li>
                </ul>

                <h2>Quick Start:</h2>
                <pre>
# Test health
curl http://localhost:${port}/health

# Create and test demo bloom filter
curl -X POST http://localhost:${port}/api/demo/bloom

# Create custom bloom filter
curl -X POST -H "Content-Type: application/json" \\
  -d '{"name":"myfilter","errorRate":0.01,"capacity":1000,"ttl":3600}' \\
  http://localhost:${port}/api/bloom/create

# Add items to bloom filter
curl -X POST -H "Content-Type: application/json" \\
  -d '{"items":["apple","banana","cherry"]}' \\
  http://localhost:${port}/api/bloom/myfilter/add

# Check items in bloom filter
curl -X POST -H "Content-Type: application/json" \\
  -d '{"items":["apple","grape"]}' \\
  http://localhost:${port}/api/bloom/myfilter/check

# Set cache with TTL
curl -X POST -H "Content-Type: application/json" \\
  -d '{"key":"user:123","value":{"name":"John","role":"admin"},"ttl":300}' \\
  http://localhost:${port}/api/cache/set

# Get cache value
curl http://localhost:${port}/api/cache/user:123

# Get cache statistics
curl http://localhost:${port}/api/cache/stats
                </pre>

                <h2>Features:</h2>
                <ul>
                    <li>✅ Redis Bloom Filter operations (create, add, check)</li>
                    <li>✅ Cache management with TTL support</li>
                    <li>✅ Auto-purging capabilities</li>
                    <li>✅ Health monitoring</li>
                    <li>✅ Comprehensive error handling</li>
                    <li>✅ Production-ready logging</li>
                </ul>
            </body>
        </html>
    `);
});

// Start server
async function startServer() {
    try {
        await redisClient.connect();
        logger.info('Connected to Redis');

        app.listen(port, '0.0.0.0', () => {
            logger.info({ port }, `Server running on port ${port}`);
            logger.info(`Access the application at: http://localhost:${port}`);
        });
    } catch (error) {
        const errorMessage = getErrorMessage(error);
        logger.error({ error: errorMessage }, 'Failed to start server');
        process.exit(1);
    }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
    logger.info('Received SIGTERM, shutting down gracefully');
    try {
        await redisClient.quit();
    } catch (error) {
        logger.error({ error: getErrorMessage(error) }, 'Error during shutdown');
    }
    process.exit(0);
});

process.on('SIGINT', async () => {
    logger.info('Received SIGINT, shutting down gracefully');
    try {
        await redisClient.quit();
    } catch (error) {
        logger.error({ error: getErrorMessage(error) }, 'Error during shutdown');
    }
    process.exit(0);
});

startServer();
