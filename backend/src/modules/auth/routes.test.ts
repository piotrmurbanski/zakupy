import assert from 'node:assert/strict';
import test from 'node:test';

import type { PrismaClient } from '@prisma/client';
import Fastify from 'fastify';
import jwt from '@fastify/jwt';
import sensible from '@fastify/sensible';

import { createAuthRoutes } from './routes.js';

const JWT_SECRET = 'test-secret';

type TestUser = {
  id: string;
  email: string;
  passwordHash: string;
  displayName: string;
  createdAt: Date;
  updatedAt: Date;
};

function buildUser(overrides: Partial<TestUser> = {}): TestUser {
  return {
    id: 'user_1',
    email: 'test@example.com',
    passwordHash: 'hashed-password',
    displayName: 'Test User',
    createdAt: new Date('2026-03-29T10:00:00.000Z'),
    updatedAt: new Date('2026-03-29T10:00:00.000Z'),
    ...overrides
  };
}

async function buildApp(userByEmail: Map<string, TestUser | undefined>, userById: Map<string, TestUser | undefined>) {
  const app = Fastify();
  const prismaMock = {
    user: {
      findUnique: async ({ where }: { where: { email?: string; id?: string } }) => {
        if ('email' in where) {
          return userByEmail.get(where.email as string) ?? null;
        }

        return userById.get(where.id as string) ?? null;
      },
      create: async ({ data }: { data: { email: string; passwordHash: string; displayName: string } }) => {
        const user = buildUser({
          email: data.email,
          passwordHash: data.passwordHash,
          displayName: data.displayName
        });

        userByEmail.set(user.email, user);
        userById.set(user.id, user);

        return user;
      }
    }
  } as unknown as Pick<PrismaClient, 'user'>;

  await app.register(sensible);
  await app.register(jwt, {
    secret: JWT_SECRET
  });
  await app.register(
    createAuthRoutes({
      prisma: prismaMock,
      hashPassword: async (password) => `hash:${password}`,
      verifyPassword: async (hash, password) => hash === `hash:${password}` || (hash === 'hashed-password' && password === 'supersecret123')
    })
  );

  await app.ready();

  return app;
}

test('POST /auth/login returns access token and user for valid credentials', async () => {
  const user = buildUser();
  const app = await buildApp(new Map([[user.email, user]]), new Map([[user.id, user]]));

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email: 'TEST@example.com',
        password: 'supersecret123'
      }
    });

    assert.equal(response.statusCode, 200);

    const body = response.json() as {
      accessToken: string;
      user: { id: string; email: string; displayName: string };
    };

    assert.equal(typeof body.accessToken, 'string');
    assert.equal(body.user.id, user.id);
    assert.equal(body.user.email, user.email);
    assert.equal(body.user.displayName, user.displayName);
  } finally {
    await app.close();
  }
});

test('POST /auth/login rejects invalid credentials', async () => {
  const user = buildUser();
  const app = await buildApp(new Map([[user.email, user]]), new Map([[user.id, user]]));

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email: 'test@example.com',
        password: 'wrong-password'
      }
    });

    assert.equal(response.statusCode, 401);
  } finally {
    await app.close();
  }
});

test('POST /auth/login rejects invalid payload', async () => {
  const app = await buildApp(new Map(), new Map());

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email: 'not-an-email',
        password: ''
      }
    });

    assert.equal(response.statusCode, 400);
  } finally {
    await app.close();
  }
});

test('GET /auth/me returns the authenticated user', async () => {
  const user = buildUser();
  const app = await buildApp(new Map([[user.email, user]]), new Map([[user.id, user]]));
  const token = await app.jwt.sign({
    sub: user.id,
    email: user.email
  });

  try {
    const response = await app.inject({
      method: 'GET',
      url: '/auth/me',
      headers: {
        authorization: `Bearer ${token}`
      }
    });

    assert.equal(response.statusCode, 200);

    const body = response.json() as {
      user: { id: string; email: string; displayName: string };
    };

    assert.equal(body.user.id, user.id);
    assert.equal(body.user.email, user.email);
    assert.equal(body.user.displayName, user.displayName);
  } finally {
    await app.close();
  }
});

test('GET /auth/me rejects missing token', async () => {
  const app = await buildApp(new Map(), new Map());

  try {
    const response = await app.inject({
      method: 'GET',
      url: '/auth/me'
    });

    assert.equal(response.statusCode, 401);
  } finally {
    await app.close();
  }
});

test('GET /auth/me rejects token for missing user', async () => {
  const app = await buildApp(new Map(), new Map());
  const token = await app.jwt.sign({
    sub: 'missing-user',
    email: 'missing@example.com'
  });

  try {
    const response = await app.inject({
      method: 'GET',
      url: '/auth/me',
      headers: {
        authorization: `Bearer ${token}`
      }
    });

    assert.equal(response.statusCode, 401);
  } finally {
    await app.close();
  }
});
