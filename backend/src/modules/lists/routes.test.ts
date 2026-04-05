import assert from 'node:assert/strict';
import test from 'node:test';

import Fastify from 'fastify';
import sensible from '@fastify/sensible';

import { hashSecret } from '../auth/session.js';
import { createListRoutes } from './routes.js';

type TestUser = {
  id: string;
  email: string;
  displayName: string;
  createdAt: Date;
  updatedAt: Date;
};

type TestList = {
  id: string;
  name: string;
  ownerUserId: string;
  createdAt: Date;
  updatedAt: Date;
  memberIds: Set<string>;
};

type TestListMember = {
  id: string;
  listId: string;
  userId: string;
  role: 'owner' | 'editor';
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
    ...overrides
  };
}

function buildList(overrides: Partial<TestList> = {}): TestList {
  return {
    id: 'list_1',
    name: 'Weekly groceries',
    ownerUserId: 'user_1',
    createdAt: new Date('2026-03-29T10:00:00.000Z'),
    updatedAt: new Date('2026-03-29T10:00:00.000Z'),
    memberIds: new Set(['user_1']),
    ...overrides
  };
}

async function buildApp(
  userById: Map<string, TestUser | undefined>,
  listsById: Map<string, TestList | undefined>,
  sessions: TestSession[] = [],
  invitations: TestInvitation[] = []
) {
  const app = Fastify();
  const membersByKey = new Map<string, TestListMember>();

  for (const list of listsById.values()) {
    if (!list) {
      continue;
    }

    for (const memberId of list.memberIds) {
      membersByKey.set(`${list.id}:${memberId}`, {
        id: `member_${membersByKey.size + 1}`,
        listId: list.id,
        userId: memberId,
        role: memberId === list.ownerUserId ? 'owner' : 'editor',
        createdAt: list.createdAt,
        updatedAt: list.updatedAt
      });
    }
  }

  const prismaMock = {
    user: {
      findUnique: async ({ where }: { where: { id?: string; email?: string } }) => {
        if (where.id) {
          return userById.get(where.id) ?? null;
        }

        if (where.email) {
          return [...userById.values()].find((user) => user?.email === where.email) ?? null;
        }

        return null;
      }
    },
    authSession: {
      findFirst: async ({
        where,
        include
      }: {
        where: { tokenHash?: string; revokedAt?: null };
        include?: { user?: boolean };
      }) => {
        const session =
          sessions.find((item) => item.tokenHash === where.tokenHash && (where.revokedAt !== null || item.revokedAt === null)) ?? null;

        if (!session) {
          return null;
        }

        if (include?.user) {
          return {
            ...session,
            user: userById.get(session.userId) ?? undefined
          };
        }

        return session;
      },
      update: async ({ where, data }: { where: { id: string }; data: { lastUsedAt?: Date } }) => {
        const session = sessions.find((item) => item.id === where.id);

        if (!session) {
          throw new Error('Session not found');
        }

        session.lastUsedAt = data.lastUsedAt ?? session.lastUsedAt;
        session.updatedAt = data.lastUsedAt ?? session.updatedAt;
        return session;
      }
    },
    shoppingList: {
      findMany: async ({ where }: { where?: { members?: { some?: { userId?: string } } } }) => {
        const userId = where?.members?.some?.userId;

        return [...listsById.values()].filter((list): list is TestList => Boolean(list && (!userId || list.memberIds.has(userId))));
      },
      findFirst: async ({
        where
      }: {
        where: {
          id?: string;
          members?: {
            some?: {
              userId?: string;
            };
          };
        };
      }) => {
        const list = where.id ? listsById.get(where.id) ?? null : null;

        if (!list) {
          return null;
        }

        const userId = where.members?.some?.userId;
        if (userId && !list.memberIds.has(userId)) {
          return null;
        }

        return list;
      },
      create: async ({
        data
      }: {
        data: {
          name: string;
          ownerUserId: string;
          members?: { create?: { userId: string; role: string } };
        };
      }) => {
        const now = new Date('2026-03-30T10:00:00.000Z');
        const list = buildList({
          id: `list_${listsById.size + 1}`,
          name: data.name,
          ownerUserId: data.ownerUserId,
          createdAt: now,
          updatedAt: now,
          memberIds: new Set([data.ownerUserId])
        });

        listsById.set(list.id, list);
        return list;
      },
      update: async ({ where, data }: { where: { id: string }; data: { name?: string } }) => {
        const list = listsById.get(where.id);

        if (!list) {
          throw new Error('List not found');
        }

        const updated = { ...list, name: data.name ?? list.name, updatedAt: new Date('2026-03-30T10:00:00.000Z') };
        listsById.set(where.id, updated);
        return updated;
      },
      delete: async ({ where }: { where: { id: string } }) => {
        const list = listsById.get(where.id);

        if (!list) {
          throw new Error('List not found');
        }

        listsById.delete(where.id);
        return list;
      }
    },
    listMember: {
      findUnique: async ({ where }: { where: { listId_userId: { listId: string; userId: string } } }) =>
        membersByKey.get(`${where.listId_userId.listId}:${where.listId_userId.userId}`) ?? null,
      create: async ({
        data,
        include
      }: {
        data: { listId: string; userId: string; role: 'owner' | 'editor' };
        include?: { user?: boolean };
      }) => {
        const list = listsById.get(data.listId);
        const user = userById.get(data.userId);

        if (!list || !user) {
          throw new Error('Cannot create list member');
        }

        list.memberIds.add(data.userId);
        const member: TestListMember = {
          id: `member_${membersByKey.size + 1}`,
          listId: data.listId,
          userId: data.userId,
          role: data.role,
          createdAt: new Date('2026-03-30T10:00:00.000Z'),
          updatedAt: new Date('2026-03-30T10:00:00.000Z')
        };
        membersByKey.set(`${data.listId}:${data.userId}`, member);

        return include?.user ? { ...member, user } : member;
      },
      delete: async ({ where }: { where: { listId_userId: { listId: string; userId: string } } }) => {
        const key = `${where.listId_userId.listId}:${where.listId_userId.userId}`;
        const member = membersByKey.get(key);
        const list = listsById.get(where.listId_userId.listId);

        if (!member || !list) {
          throw new Error('Member not found');
        }

        list.memberIds.delete(where.listId_userId.userId);
        membersByKey.delete(key);
        return member;
      }
    },
    listInvitation: {
      findUnique: async ({ where }: { where: { listId_email: { listId: string; email: string } } }) =>
        invitations.find((item) => item.listId === where.listId_email.listId && item.email === where.listId_email.email) ?? null,
      create: async ({ data }: { data: { listId: string; email: string; role: 'owner' | 'editor'; invitedByUserId: string } }) => {
        const invitation: TestInvitation = {
          id: `invite_${invitations.length + 1}`,
          listId: data.listId,
          email: data.email,
          role: data.role,
          invitedByUserId: data.invitedByUserId,
          claimedByUserId: null,
          claimedAt: null,
          createdAt: new Date('2026-03-30T10:00:00.000Z'),
          updatedAt: new Date('2026-03-30T10:00:00.000Z')
        };

        invitations.push(invitation);
        return invitation;
      }
    }
  };

  await app.register(sensible);
  await app.register(createListRoutes({ prisma: prismaMock as never }));
  await app.ready();
  return { app, invitations };
}

function buildSessionToken(userId: string) {
  const rawToken = `session-${userId}`;

  const session: TestSession = {
    id: `sess-${userId}`,
    userId,
    tokenHash: hashSecret(rawToken),
    expiresAt: new Date('2026-07-01T00:00:00.000Z'),
    revokedAt: null,
    lastUsedAt: new Date('2026-04-01T00:00:00.000Z'),
    createdAt: new Date('2026-04-01T00:00:00.000Z'),
    updatedAt: new Date('2026-04-01T00:00:00.000Z')
  };

  return { rawToken, session };
}

test('POST /lists creates a list for the authenticated user', async () => {
  const user = buildUser();
  const lists = new Map<string, TestList | undefined>();
  const { rawToken, session } = buildSessionToken(user.id);
  const { app } = await buildApp(new Map([[user.id, user]]), lists, [session]);

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/lists',
      headers: { authorization: `Bearer ${rawToken}` },
      payload: { name: '  Weekend groceries  ' }
    });

    assert.equal(response.statusCode, 201);
    assert.equal(response.json().list.name, 'Weekend groceries');
    assert.equal(lists.size, 1);
  } finally {
    await app.close();
  }
});

test('GET /lists returns only lists visible to the user', async () => {
  const user = buildUser();
  const otherUser = buildUser({ id: 'user_2', email: 'other@example.com' });
  const sharedList = buildList({ id: 'list_1', name: 'Shared list', ownerUserId: user.id, memberIds: new Set([user.id, otherUser.id]) });
  const privateList = buildList({ id: 'list_2', name: 'Private list', ownerUserId: otherUser.id, memberIds: new Set([otherUser.id]) });
  const { rawToken, session } = buildSessionToken(user.id);
  const { app } = await buildApp(
    new Map([
      [user.id, user],
      [otherUser.id, otherUser]
    ]),
    new Map([
      [sharedList.id, sharedList],
      [privateList.id, privateList]
    ]),
    [session]
  );

  try {
    const response = await app.inject({
      method: 'GET',
      url: '/lists',
      headers: { authorization: `Bearer ${rawToken}` }
    });

    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json().items.map((item: { name: string }) => item.name), ['Shared list']);
  } finally {
    await app.close();
  }
});

test('PATCH /lists/:listId rejects non-owner edits', async () => {
  const owner = buildUser();
  const editor = buildUser({ id: 'user_2', email: 'editor@example.com' });
  const list = buildList({ id: 'list_1', ownerUserId: owner.id, memberIds: new Set([owner.id, editor.id]) });
  const { rawToken, session } = buildSessionToken(editor.id);
  const { app } = await buildApp(
    new Map([
      [owner.id, owner],
      [editor.id, editor]
    ]),
    new Map([[list.id, list]]),
    [session]
  );

  try {
    const response = await app.inject({
      method: 'PATCH',
      url: `/lists/${list.id}`,
      headers: { authorization: `Bearer ${rawToken}` },
      payload: { name: 'Updated by editor' }
    });

    assert.equal(response.statusCode, 403);
  } finally {
    await app.close();
  }
});

test('GET /lists rejects missing token', async () => {
  const user = buildUser();
  const { app } = await buildApp(new Map([[user.id, user]]), new Map());

  try {
    const response = await app.inject({ method: 'GET', url: '/lists' });
    assert.equal(response.statusCode, 401);
  } finally {
    await app.close();
  }
});

test('POST /lists/:listId/members adds an editor by email for the owner', async () => {
  const owner = buildUser();
  const invitedUser = buildUser({ id: 'user_2', email: 'editor@example.com', displayName: 'Editor' });
  const list = buildList({ id: 'list_1', ownerUserId: owner.id, memberIds: new Set([owner.id]) });
  const { rawToken, session } = buildSessionToken(owner.id);
  const { app } = await buildApp(
    new Map([
      [owner.id, owner],
      [invitedUser.id, invitedUser]
    ]),
    new Map([[list.id, list]]),
    [session]
  );

  try {
    const response = await app.inject({
      method: 'POST',
      url: `/lists/${list.id}/members`,
      headers: { authorization: `Bearer ${rawToken}` },
      payload: { email: 'EDITOR@example.com' }
    });

    assert.equal(response.statusCode, 201);
    assert.equal(response.json().member.userId, invitedUser.id);
    assert.equal(list.memberIds.has(invitedUser.id), true);
  } finally {
    await app.close();
  }
});

test('POST /lists/:listId/members creates a pending invitation for an unknown email', async () => {
  const owner = buildUser();
  const list = buildList({ id: 'list_1', ownerUserId: owner.id, memberIds: new Set([owner.id]) });
  const { rawToken, session } = buildSessionToken(owner.id);
  const { app, invitations } = await buildApp(new Map([[owner.id, owner]]), new Map([[list.id, list]]), [session]);

  try {
    const response = await app.inject({
      method: 'POST',
      url: `/lists/${list.id}/members`,
      headers: { authorization: `Bearer ${rawToken}` },
      payload: { email: 'missing@example.com' }
    });

    assert.equal(response.statusCode, 202);
    assert.equal(response.json().invitation.email, 'missing@example.com');
    assert.equal(invitations.length, 1);
  } finally {
    await app.close();
  }
});

test('POST /lists/:listId/members rejects duplicate membership', async () => {
  const owner = buildUser();
  const editor = buildUser({ id: 'user_2', email: 'editor@example.com' });
  const list = buildList({ id: 'list_1', ownerUserId: owner.id, memberIds: new Set([owner.id, editor.id]) });
  const { rawToken, session } = buildSessionToken(owner.id);
  const { app } = await buildApp(
    new Map([
      [owner.id, owner],
      [editor.id, editor]
    ]),
    new Map([[list.id, list]]),
    [session]
  );

  try {
    const response = await app.inject({
      method: 'POST',
      url: `/lists/${list.id}/members`,
      headers: { authorization: `Bearer ${rawToken}` },
      payload: { email: editor.email }
    });

    assert.equal(response.statusCode, 409);
  } finally {
    await app.close();
  }
});

test('DELETE /lists/:listId/members/:userId removes an editor for the owner', async () => {
  const owner = buildUser();
  const editor = buildUser({ id: 'user_2', email: 'editor@example.com' });
  const list = buildList({ id: 'list_1', ownerUserId: owner.id, memberIds: new Set([owner.id, editor.id]) });
  const { rawToken, session } = buildSessionToken(owner.id);
  const { app } = await buildApp(
    new Map([
      [owner.id, owner],
      [editor.id, editor]
    ]),
    new Map([[list.id, list]]),
    [session]
  );

  try {
    const response = await app.inject({
      method: 'DELETE',
      url: `/lists/${list.id}/members/${editor.id}`,
      headers: { authorization: `Bearer ${rawToken}` }
    });

    assert.equal(response.statusCode, 204);
    assert.equal(list.memberIds.has(editor.id), false);
  } finally {
    await app.close();
  }
});
