import assert from 'node:assert/strict';
import test from 'node:test';

import Fastify from 'fastify';
import sensible from '@fastify/sensible';

import { hashSecret } from '../auth/session.js';
import { createInvitationRoutes } from './routes.js';

type TestUser = {
  id: string;
  email: string;
  displayName: string;
  createdAt: Date;
  updatedAt: Date;
};

type TestSession = {
  id: string;
  userId: string;
  tokenHash: string;
  expiresAt: Date;
  revokedAt: Date | null;
  lastUsedAt: Date;
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
    ...overrides,
  };
}

async function buildApp(options: {
  users: TestUser[];
  sessions: TestSession[];
  invitations: TestInvitation[];
}) {
  const app = Fastify();
  const users = new Map(options.users.map((user) => [user.id, user]));
  const sessions = [...options.sessions];
  const invitations = [...options.invitations];
  const memberships = new Set<string>();

  const prismaMock = {
    user: {
      findUnique: async ({ where }: { where: { id?: string; email?: string } }) => {
        if (where.id) {
          return users.get(where.id) ?? null;
        }

        return [...users.values()].find((user) => user.email === where.email) ?? null;
      },
    },
    authSession: {
      findFirst: async ({
        where,
        include,
      }: {
        where: { tokenHash?: string; revokedAt?: null };
        include?: { user?: boolean };
      }) => {
        const session =
          sessions.find((item) => item.tokenHash === where.tokenHash && item.revokedAt === null) ?? null;

        if (!session) {
          return null;
        }

        if (include?.user) {
          return {
            ...session,
            user: users.get(session.userId) ?? undefined,
          };
        }

        return session;
      },
      update: async ({
        where,
        data,
      }: {
        where: { id: string };
        data: { lastUsedAt?: Date };
      }) => {
        const session = sessions.find((item) => item.id === where.id);

        if (!session) {
          throw new Error('Session not found');
        }

        session.lastUsedAt = data.lastUsedAt ?? session.lastUsedAt;
        session.updatedAt = data.lastUsedAt ?? session.updatedAt;
        return session;
      },
    },
    listInvitation: {
      findMany: async ({
        where,
        include,
      }: {
        where: { email?: string; claimedAt?: null };
        include?: { list?: boolean; invitedByUser?: boolean };
      }) =>
        invitations
          .filter((invitation) => {
            if (where.email && invitation.email !== where.email) {
              return false;
            }

            if (where.claimedAt === null && invitation.claimedAt !== null) {
              return false;
            }

            return true;
          })
          .map((invitation) => ({
            ...invitation,
            list: include?.list
                ? {
                    id: invitation.listId,
                    name: invitation.listId === 'list_1' ? 'Weekly groceries' : 'Weekend snacks',
                  }
                : undefined,
            invitedByUser: include?.invitedByUser
                ? users.get(invitation.invitedByUserId) ?? undefined
                : undefined,
          })),
      findFirst: async ({
        where,
        include,
      }: {
        where: { id?: string; email?: string; claimedAt?: null };
        include?: { list?: boolean; invitedByUser?: boolean };
      }) => {
        const invitation =
          invitations.find((item) => {
            if (where.id && item.id !== where.id) {
              return false;
            }

            if (where.email && item.email !== where.email) {
              return false;
            }

            if (where.claimedAt === null && item.claimedAt !== null) {
              return false;
            }

            return true;
          }) ?? null;

        if (!invitation) {
          return null;
        }

        return {
          ...invitation,
          list: include?.list
              ? {
                  id: invitation.listId,
                  name: invitation.listId === 'list_1' ? 'Weekly groceries' : 'Weekend snacks',
                }
              : undefined,
          invitedByUser: include?.invitedByUser
              ? users.get(invitation.invitedByUserId) ?? undefined
              : undefined,
        };
      },
      update: async ({
        where,
        data,
      }: {
        where: { id: string };
        data: { claimedAt?: Date; claimedByUserId?: string };
      }) => {
        const invitation = invitations.find((item) => item.id === where.id);

        if (!invitation) {
          throw new Error('Invitation not found');
        }

        invitation.claimedAt = data.claimedAt ?? invitation.claimedAt;
        invitation.claimedByUserId =
          data.claimedByUserId ?? invitation.claimedByUserId;
        invitation.updatedAt = data.claimedAt ?? invitation.updatedAt;
        return invitation;
      },
    },
    listMember: {
      findUnique: async ({
        where,
      }: {
        where: { listId_userId: { listId: string; userId: string } };
      }) =>
        memberships.has(`${where.listId_userId.listId}:${where.listId_userId.userId}`)
            ? {}
            : null,
      create: async ({
        data,
      }: {
        data: { listId: string; userId: string; role: 'owner' | 'editor' };
      }) => {
        memberships.add(`${data.listId}:${data.userId}`);
        return data;
      },
    },
  };

  await app.register(sensible);
  await app.register(
    createInvitationRoutes({
      prisma: prismaMock as never,
      now: () => new Date('2026-04-09T20:00:00.000Z'),
    }),
  );
  await app.ready();

  return { app, invitations, memberships };
}

function buildSession(userId: string) {
  const token = `token-${userId}`;

  return {
    token,
    session: {
      id: `session-${userId}`,
      userId,
      tokenHash: hashSecret(token),
      expiresAt: new Date('2026-07-01T00:00:00.000Z'),
      revokedAt: null,
      lastUsedAt: new Date('2026-04-01T00:00:00.000Z'),
      createdAt: new Date('2026-04-01T00:00:00.000Z'),
      updatedAt: new Date('2026-04-01T00:00:00.000Z'),
    },
  };
}

test('GET /invitations returns pending invitations for the signed-in user', async () => {
  const user = buildUser();
  const inviter = buildUser({
    id: 'user_2',
    email: 'owner@example.com',
    displayName: 'Owner',
  });
  const invitation: TestInvitation = {
    id: 'invite_1',
    listId: 'list_1',
    email: user.email,
    role: 'editor',
    invitedByUserId: inviter.id,
    claimedByUserId: null,
    claimedAt: null,
    createdAt: new Date('2026-04-09T10:00:00.000Z'),
    updatedAt: new Date('2026-04-09T10:00:00.000Z'),
  };
  const { token, session } = buildSession(user.id);
  const { app } = await buildApp({
    users: [user, inviter],
    sessions: [session],
    invitations: [invitation],
  });

  try {
    const response = await app.inject({
      method: 'GET',
      url: '/invitations',
      headers: {
        authorization: `Bearer ${token}`,
      },
    });

    assert.equal(response.statusCode, 200);
    assert.equal(response.json().items.length, 1);
    assert.equal(response.json().items[0].listName, 'Weekly groceries');
    assert.equal(response.json().items[0].invitedByUser.email, inviter.email);
  } finally {
    await app.close();
  }
});

test('POST /invitations/:invitationId/accept claims the invitation and creates membership', async () => {
  const user = buildUser();
  const inviter = buildUser({
    id: 'user_2',
    email: 'owner@example.com',
    displayName: 'Owner',
  });
  const invitation: TestInvitation = {
    id: 'invite_1',
    listId: 'list_1',
    email: user.email,
    role: 'editor',
    invitedByUserId: inviter.id,
    claimedByUserId: null,
    claimedAt: null,
    createdAt: new Date('2026-04-09T10:00:00.000Z'),
    updatedAt: new Date('2026-04-09T10:00:00.000Z'),
  };
  const { token, session } = buildSession(user.id);
  const { app, invitations, memberships } = await buildApp({
    users: [user, inviter],
    sessions: [session],
    invitations: [invitation],
  });

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/invitations/invite_1/accept',
      headers: {
        authorization: `Bearer ${token}`,
      },
    });

    assert.equal(response.statusCode, 200);
    assert.equal(response.json().status, 'accepted');
    assert.notEqual(invitations[0]?.claimedAt, null);
    assert.equal(invitations[0]?.claimedByUserId, user.id);
    assert.equal(memberships.has(`list_1:${user.id}`), true);
  } finally {
    await app.close();
  }
});

test('POST /invitations/:invitationId/accept returns 404 for another user invitation', async () => {
  const user = buildUser();
  const inviter = buildUser({
    id: 'user_2',
    email: 'owner@example.com',
    displayName: 'Owner',
  });
  const invitation: TestInvitation = {
    id: 'invite_1',
    listId: 'list_1',
    email: 'someone-else@example.com',
    role: 'editor',
    invitedByUserId: inviter.id,
    claimedByUserId: null,
    claimedAt: null,
    createdAt: new Date('2026-04-09T10:00:00.000Z'),
    updatedAt: new Date('2026-04-09T10:00:00.000Z'),
  };
  const { token, session } = buildSession(user.id);
  const { app } = await buildApp({
    users: [user, inviter],
    sessions: [session],
    invitations: [invitation],
  });

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/invitations/invite_1/accept',
      headers: {
        authorization: `Bearer ${token}`,
      },
    });

    assert.equal(response.statusCode, 404);
  } finally {
    await app.close();
  }
});
