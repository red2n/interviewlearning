import { createClient } from 'redis';

const client = createClient();

client.on('error', (err: any) => console.log('Redis Client Error', err));

await client.connect(); // ✅ works in redis@4

await client.set('key', 'value');
const value = await client.get('key');
console.log('GET key:', value);
