import RedisMock from 'ioredis-mock';

/** In-memory Redis for tests — proves real cache-aside behavior without a real Redis server. */
export function createTestRedis() {
  return new RedisMock();
}
