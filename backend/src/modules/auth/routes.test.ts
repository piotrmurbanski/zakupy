import assert from 'node:assert/strict';
import test from 'node:test';

import argon2 from 'argon2';

import { buildApp } from '../../app.js';
import type { AuthPrisma, UserRecord } from '../../lib/types.js';

function createAuthPrisma(initialUsers: UserRecord[] = []) {
  const users = new Map(initialUsers.map((user) => [user.id, user]));

  const prisma: AuthPrisma = {
    user: {
      async findUnique({ where }) {
        if (where.id) {
          return users.get(where.id) ?? null;
        }

        if (where.email) {
          return [...users.values()].find((user) => user.email === where.email) ?? null;
        }

        return null;
      },
      async create({ data }) {
        const now = new Date();
        const user: UserRecord = {
          id: `user_${users.size + 1}`,
          email: data.email,
          passwordHash: data.passwordHash,
          displayName: data.displayName,
          createdAt: now,
          updatedAt: now
        };

        users.set(user.id, user);

        return user;
      }
    }
  };

  return { prisma };
}

test('POST /auth/login returns token and user for valid credentials', async () => {
  const passwordHash = await argon2.hash('supersecret123', {
    type: argon2.argon2id
  });
  const existingUser: UserRecord = {
    id: 'user_1',
    email: 'test@example.com',
    passwordHash,
    displayName: 'Piotr',
    createdAt: new Date('2026-03-29T10:00:00.000Z'),
    updatedAt: new Date('2026-03-29T10:00:00.000Z')
  };
  const { prisma } = createAuthPrisma([existingUser]);
  const app = await buildApp({ prisma });

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
    const body = response.json();
    assert.equal(typeof body.accessToken, 'string');
    assert.equal(body.user.id, existingUser.id);
    assert.equal(body.user.email, existingUser.email);
  } finally {
    await app.close();
  }
});

test('POST /auth/login rejects an unknown email', async () => {
  const { prisma } = createAuthPrisma();
  const app = await buildApp({ prisma });

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email: 'test@example.com',
        password: 'supersecret123'
      }
    });

    assert.equal(response.statusCode, 401);
    assert.match(response.body, /Invalid email or password/);
  } finally {
    await app.close();
  }
});

test('POST /auth/login rejects an invalid password', async () => {
  const passwordHash = await argon2.hash('supersecret123', {
    type: argon2.argon2id
  });
  const existingUser: UserRecord = {
    id: 'user_1',
    email: 'test@example.com',
    passwordHash,
    displayName: 'Piotr',
    createdAt: new Date('2026-03-29T10:00:00.000Z'),
    updatedAt: new Date('2026-03-29T10:00:00.000Z')
  };
  const { prisma } = createAuthPrisma([existingUser]);
  const app = await buildApp({ prisma });

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/auth/login',
      payload: {
        email: 'test@example.com',
        password: 'wrongpass123'
      }
    });

    assert.equal(response.statusCode, 401);
    assert.match(response.body, /Invalid email or password/);
  } finally {
    await app.close();
  }
});

test('GET /auth/me returns the current user for a valid token', async () => {
  const existingUser: UserRecord = {
    id: 'user_1',
    email: 'test@example.com',
    passwordHash: 'unused',
    displayName: 'Piotr',
    createdAt: new Date('2026-03-29T10:00:00.000Z'),
    updatedAt: new Date('2026-03-29T10:00:00.000Z')
  };
  const { prisma } = createAuthPrisma([existingUser]);
  const app = await buildApp({ prisma });

  try {
    const accessToken = await app.jwt.sign({
      sub: existingUser.id,
      email: existingUser.email
    });

    const response = await app.inject({
      method: 'GET',
      url: '/auth/me',
      headers: {
        authorization: `Bearer ${accessToken}`
      }
    });

    assert.equal(response.statusCode, 200);
    const body = response.json();
    assert.equal(body.user.id, existingUser.id);
    assert.equal(body.user.email, existingUser.email);
  } finally {
    await app.close();
  }
});

test('GET /auth/me rejects a missing token', async () => {
  const { prisma } = createAuthPrisma();
  const app = await buildApp({ prisma });

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
