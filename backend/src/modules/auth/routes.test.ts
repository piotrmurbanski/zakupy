import assert from 'node:assert/strict';
import test from 'node:test';

import Fastify from 'fastify';
import sensible from '@fastify/sensible';

import { createAuthRoutes } from './routes.js';
import { hashSecret } from './session.js';

type TestUser = {
  id: string;
  email: string;
  displayName: string;
  createdAt: Date;
  updatedAt: Date;
};

type TestAuthCode = {
  id: string;
  email: string;
  codeHash: string;
  expiresAt: Date;
  consumedAt: Date | null;
  attemptCount: number;
  createdAt: Date;
  updatedAt: Date;
};

type TestSession = {
  id: string;
  userId: string;
  tokenHash: string;
  deviceLabel: string | null;
  lastUsedAt: Date;
  expiresAt: Date;
  revokedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
};

type TestInvitation = {
  id: string;
  listId: string;
  email: string;
  role: 'owner' | 'editor';
  invitedByUserId: string;
  claimedByUserId: string | null;
  claimedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
};

function buildUser(overrides: Partial<TestUser> = {}): TestUser {
  return {
    id: 'user_1',
    email: 'test@example.com',
    displayName: 'Test User',
    createdAt: new Date('2026-03-29T10:00:00.000Z'),
    updatedAt: new Date('2026-03-29T10:00:00.000Z'),
    ...overrides
  };
}

async function buildApp(options: {
  now?: Date;
  users?: TestUser[];
  authCodes?: TestAuthCode[];
  sessions?: TestSession[];
  invitations?: TestInvitation[];
}) {
  const app = Fastify();
  const now = options.now ?? new Date('2026-04-05T20:00:00.000Z');
  const sentCodes: Array<{ email: string; code: string }> = [];
  const users = new Map((options.users ?? []).map((user) => [user.id, user]));
  const authCodes = [...(options.authCodes ?? [])];
  const sessions = [...(options.sessions ?? [])];
  const invitations = [...(options.invitations ?? [])];
  const memberships = new Set<string>();

  const prismaMock = {
    user: {
      findUnique: async ({ where }: { where: { id?: string; email?: string } }) => {
        if (where.id) {
          return users.get(where.id) ?? null;
        }

        return [...users.values()].find((user) => user.email === where.email) ?? null;
      },
      create: async ({ data }: { data: { email: string; displayName: string } }) => {
        const user = buildUser({
          id: `user_${users.size + 1}`,
          email: data.email,
          displayName: data.displayName,
          createdAt: now,
          updatedAt: now
        });

        users.set(user.id, user);
        return user;
      }
    },
    authCode: {
      findFirst: async ({
        where,
        orderBy
      }: {
        where: { email?: string; consumedAt?: null };
        orderBy?: { createdAt: 'asc' | 'desc' };
      }) => {
        let items = authCodes.filter((code) => {
          if (where.email && code.email !== where.email) {
            return false;
          }

          if (where.consumedAt === null && code.consumedAt !== null) {
            return false;
          }

          return true;
        });

        if (orderBy?.createdAt === 'desc') {
          items = items.sort((left, right) => right.createdAt.getTime() - left.createdAt.getTime());
        }

        return items[0] ?? null;
      },
      create: async ({ data }: { data: { email: string; codeHash: string; expiresAt: Date } }) => {
        const authCode: TestAuthCode = {
          id: `code_${authCodes.length + 1}`,
          email: data.email,
          codeHash: data.codeHash,
          expiresAt: data.expiresAt,
          consumedAt: null,
          attemptCount: 0,
          createdAt: now,
          updatedAt: now
        };

        authCodes.push(authCode);
        return authCode;
      },
      update: async ({ where, data }: { where: { id: string }; data: { consumedAt?: Date; attemptCount?: number } }) => {
        const authCode = authCodes.find((item) => item.id === where.id);

        if (!authCode) {
          throw new Error('Auth code not found');
        }

        if (data.consumedAt !== undefined) {
          authCode.consumedAt = data.consumedAt;
        }

        if (data.attemptCount !== undefined) {
          authCode.attemptCount = data.attemptCount;
        }

        authCode.updatedAt = now;
        return authCode;
      }
    },
    authSession: {
      findFirst: async ({
        where,
        include
      }: {
        where: { tokenHash?: string; userId?: string; revokedAt?: null };
        include?: { user?: boolean };
      }) => {
        const session =
          sessions.find((item) => {
            if (where.tokenHash && item.tokenHash !== where.tokenHash) {
              return false;
            }

            if (where.userId && item.userId !== where.userId) {
              return false;
            }

            if (where.revokedAt === null && item.revokedAt !== null) {
              return false;
            }

            return true;
          }) ?? null;

        if (!session) {
          return null;
        }

        if (include?.user) {
          return {
            ...session,
            user: users.get(session.userId) ?? undefined
          };
        }

        return session;
      },
      create: async ({ data }: { data: { userId: string; tokenHash: string; expiresAt: Date; deviceLabel?: string | null } }) => {
        const session: TestSession = {
          id: `session_${sessions.length + 1}`,
          userId: data.userId,
          tokenHash: data.tokenHash,
          deviceLabel: data.deviceLabel ?? null,
          lastUsedAt: now,
          expiresAt: data.expiresAt,
          revokedAt: null,
          createdAt: now,
          updatedAt: now
        };

        sessions.push(session);
        return session;
      },
      update: async ({ where, data }: { where: { id: string }; data: { revokedAt?: Date; lastUsedAt?: Date } }) => {
        const session = sessions.find((item) => item.id === where.id);

        if (!session) {
          throw new Error('Session not found');
        }

        if (data.revokedAt !== undefined) {
          session.revokedAt = data.revokedAt;
        }

        if (data.lastUsedAt !== undefined) {
          session.lastUsedAt = data.lastUsedAt;
        }

        session.updatedAt = now;
        return session;
      }
    },
    listInvitation: {
      findMany: async ({ where }: { where: { email?: string; claimedAt?: null } }) =>
        invitations.filter((invitation) => {
          if (where.email && invitation.email !== where.email) {
            return false;
          }

          if (where.claimedAt === null && invitation.claimedAt !== null) {
            return false;
          }

          return true;
        }),
      update: async ({ where, data }: { where: { id: string }; data: { claimedAt?: Date; claimedByUserId?: string } }) => {
        const invitation = invitations.find((item) => item.id === where.id);

        if (!invitation) {
          throw new Error('Invitation not found');
        }

        invitation.claimedAt = data.claimedAt ?? invitation.claimedAt;
        invitation.claimedByUserId = data.claimedByUserId ?? invitation.claimedByUserId;
        invitation.updatedAt = now;
        return invitation;
      }
    },
    listMember: {
      findUnique: async ({ where }: { where: { listId_userId: { listId: string; userId: string } } }) =>
        memberships.has(`${where.listId_userId.listId}:${where.listId_userId.userId}`) ? {} : null,
      create: async ({ data }: { data: { listId: string; userId: string; role: 'owner' | 'editor' } }) => {
        memberships.add(`${data.listId}:${data.userId}`);
        return { ...data };
      }
    }
  };

  await app.register(sensible);
  await app.register(
    createAuthRoutes({
      prisma: prismaMock as never,
      now: () => now,
      sendAuthCode: async ({ email, code }) => {
        sentCodes.push({ email, code });
      }
    })
  );

  await app.ready();

  return { app, authCodes, sentCodes, sessions, users, invitations, memberships };
}

test('POST /auth/request-code creates a code and sends it', async () => {
  const { app, sentCodes, authCodes } = await buildApp({});

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/auth/request-code',
      payload: {
        email: 'TEST@example.com'
      }
    });

    assert.equal(response.statusCode, 202);
    assert.equal(response.json().status, 'code_sent');
    assert.equal(sentCodes.length, 1);
    assert.equal(sentCodes[0]?.email, 'test@example.com');
    assert.equal(authCodes.length, 1);
  } finally {
    await app.close();
  }
});

test('POST /auth/verify-code creates a user, claims invitations, and returns a session token', async () => {
  const authCode: TestAuthCode = {
    id: 'code_1',
    email: 'test@example.com',
    codeHash: hashSecret('123456'),
    expiresAt: new Date('2026-04-05T20:10:00.000Z'),
    consumedAt: null,
    attemptCount: 0,
    createdAt: new Date('2026-04-05T20:00:00.000Z'),
    updatedAt: new Date('2026-04-05T20:00:00.000Z')
  };
  const invitation: TestInvitation = {
    id: 'invite_1',
    listId: 'list_1',
    email: 'test@example.com',
    role: 'editor',
    invitedByUserId: 'user_owner',
    claimedByUserId: null,
    claimedAt: null,
    createdAt: new Date('2026-04-05T20:00:00.000Z'),
    updatedAt: new Date('2026-04-05T20:00:00.000Z')
  };
  const { app, sessions, users, invitations, memberships } = await buildApp({
    authCodes: [authCode],
    invitations: [invitation]
  });

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/auth/verify-code',
      payload: {
        email: 'test@example.com',
        code: '123456',
        displayName: 'Piotr'
      }
    });

    assert.equal(response.statusCode, 200);
    const body = response.json() as {
      sessionToken: string;
      user: { email: string; displayName: string; id: string };
    };

    assert.equal(typeof body.sessionToken, 'string');
    assert.equal(body.user.email, 'test@example.com');
    assert.equal(body.user.displayName, 'Piotr');
    assert.equal(sessions.length, 1);
    assert.equal([...users.values()].length, 1);
    assert.equal(invitations[0]?.claimedByUserId, body.user.id);
    assert.equal(memberships.has(`list_1:${body.user.id}`), true);
  } finally {
    await app.close();
  }
});

test('POST /auth/verify-code rejects an invalid code and increments attempts', async () => {
  const authCode: TestAuthCode = {
    id: 'code_1',
    email: 'test@example.com',
    codeHash: hashSecret('123456'),
    expiresAt: new Date('2026-04-05T20:10:00.000Z'),
    consumedAt: null,
    attemptCount: 0,
    createdAt: new Date('2026-04-05T20:00:00.000Z'),
    updatedAt: new Date('2026-04-05T20:00:00.000Z')
  };
  const { app, authCodes } = await buildApp({
    authCodes: [authCode]
  });

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/auth/verify-code',
      payload: {
        email: 'test@example.com',
        code: '000000'
      }
    });

    assert.equal(response.statusCode, 401);
    assert.equal(authCodes[0]?.attemptCount, 1);
  } finally {
    await app.close();
  }
});

test('GET /auth/me returns the authenticated user for a valid session', async () => {
  const user = buildUser();
  const rawToken = 'valid-session-token';
  const { app } = await buildApp({
    users: [user],
    sessions: [
      {
        id: 'session_1',
        userId: user.id,
        tokenHash: hashSecret(rawToken),
        deviceLabel: null,
        lastUsedAt: new Date('2026-04-05T20:00:00.000Z'),
        expiresAt: new Date('2026-07-05T20:00:00.000Z'),
        revokedAt: null,
        createdAt: new Date('2026-04-05T20:00:00.000Z'),
        updatedAt: new Date('2026-04-05T20:00:00.000Z')
      }
    ]
  });

  try {
    const response = await app.inject({
      method: 'GET',
      url: '/auth/me',
      headers: {
        authorization: `Bearer ${rawToken}`
      }
    });

    assert.equal(response.statusCode, 200);
    assert.equal(response.json().user.email, user.email);
  } finally {
    await app.close();
  }
});

test('POST /auth/logout revokes the current session', async () => {
  const user = buildUser();
  const rawToken = 'valid-session-token';
  const { app, sessions } = await buildApp({
    users: [user],
    sessions: [
      {
        id: 'session_1',
        userId: user.id,
        tokenHash: hashSecret(rawToken),
        deviceLabel: null,
        lastUsedAt: new Date('2026-04-05T20:00:00.000Z'),
        expiresAt: new Date('2026-07-05T20:00:00.000Z'),
        revokedAt: null,
        createdAt: new Date('2026-04-05T20:00:00.000Z'),
        updatedAt: new Date('2026-04-05T20:00:00.000Z')
      }
    ]
  });

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/auth/logout',
      headers: {
        authorization: `Bearer ${rawToken}`
      }
    });

    assert.equal(response.statusCode, 200);
    assert.equal(response.json().status, 'logged_out');
    assert.notEqual(sessions[0]?.revokedAt, null);
  } finally {
    await app.close();
  }
});
