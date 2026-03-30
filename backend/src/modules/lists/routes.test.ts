import assert from 'node:assert/strict';
import test from 'node:test';

import Fastify from 'fastify';
import jwt from '@fastify/jwt';

import { listRoutes } from './routes.js';

const JWT_SECRET = 'test-secret';

test('GET /lists rejects missing token', async () => {
  const app = Fastify();
  await app.register(jwt, { secret: JWT_SECRET });
  await app.register(listRoutes);
  await app.ready();

  try {
    const response = await app.inject({
      method: 'GET',
      url: '/lists'
    });

    assert.equal(response.statusCode, 401);
  } finally {
    await app.close();
  }
});

test('GET /lists returns payload for authenticated user', async () => {
  const app = Fastify();
  await app.register(jwt, { secret: JWT_SECRET });
  await app.register(listRoutes);
  await app.ready();

  const token = await app.jwt.sign({
    sub: 'user_1',
    email: 'test@example.com'
  });

  try {
    const response = await app.inject({
      method: 'GET',
      url: '/lists',
      headers: {
        authorization: `Bearer ${token}`
      }
    });

    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json(), { items: [] });
  } finally {
    await app.close();
  }
});
