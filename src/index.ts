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

	logger.info('Setting key in Redis');
	await client.set('key', 'value');

	logger.info('Getting key from Redis');
	const value = await client.get('key');
	logger.info({ value }, 'GET key result');

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
