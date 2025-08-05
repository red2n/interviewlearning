import { createClient } from 'redis';

const client = createClient({
    url: 'redis://localhost:6379'
});

async function test() {
    try {
        await client.connect();
        console.log('Connected to Redis');

        // Check if bf methods exist
        console.log('client.bf exists:', typeof client.bf);
        console.log('Available methods on client:', Object.getOwnPropertyNames(client));

        // Try using sendCommand instead
        const result = await client.sendCommand(['BF.RESERVE', 'test:manual', '0.01', '1000']);
        console.log('Manual BF.RESERVE result:', result);

        await client.quit();
    } catch (error) {
        console.error('Error:', error);
    }
}

test();
