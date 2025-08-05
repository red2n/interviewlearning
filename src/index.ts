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

async function main() {
	try {
		logger.info('Connecting to Redis...');
		await client.connect();
		logger.info('Connected to Redis successfully');

		const res1 = await client.bf.reserve('bikes:models', 0.01, 1000);
		logger.info({ result: res1 }, 'Bloom filter reserve result');  // >>> OK

		const res2 = await client.bf.add('bikes:models', 'Smoky Mountain Striker');
		logger.info({ result: res2 }, 'Bloom filter add result');  // >>> true

		const res3 = await client.bf.exists('bikes:models', 'Smoky Mountain Striker');
		logger.info({ result: res3 }, 'Bloom filter exists result');  // >>> true

		const res4 = await client.bf.mAdd('bikes:models', [
			'Rocky Mountain Racer',
			'Cloudy City Cruiser',
			'Windy City Wippet'
		]);
		logger.info({ result: res4 }, 'Bloom filter mAdd result');  // >>> [true, true, true]

		const res5 = await client.bf.mExists('bikes:models', [
			'Rocky Mountain Racer',
			'Cloudy City Cruiser',
			'Windy City Wippet'
		]);
		logger.info({ result: res5 }, 'Bloom filter mExists result');  // >>> [true, true, true]


		await client.quit();
		logger.info('Redis connection closed');
	} catch (error) {
		logger.error({ error }, 'Error in Redis operations');
		process.exit(1);
	}
}

main().catch(error => {
	logger.fatal({ error }, 'Unhandled error in main function');
	process.exit(1);
});

// Handle graceful shutdown on Ctrl+C
process.on('SIGINT', async () => {
	logger.info('Received SIGINT signal (Ctrl+C). Shutting down gracefully...');
	try {
		if (client.isOpen) {
			await client.quit();
			logger.info('Redis connection closed');
		}
	} catch (err) {
		logger.error({ err }, 'Error closing Redis connection during shutdown');
	} finally {
		process.exit(0);
	}
});
