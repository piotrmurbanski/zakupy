import assert from 'node:assert/strict';
import test from 'node:test';

import Fastify from 'fastify';
import sensible from '@fastify/sensible';

import { hashSecret } from '../auth/session.js';
import { createItemRoutes } from './routes.js';

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

type TestItem = {
  id: string;
  listId: string;
  name: string;
  quantity: string | null;
  unit: string | null;
  isChecked: boolean;
  sortOrder: number;
  createdByUserId: string;
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

function buildItem(overrides: Partial<TestItem> = {}): TestItem {
  return {
    id: 'item_1',
    listId: 'list_1',
    name: 'Milk',
    quantity: '2',
    unit: 'l',
    isChecked: false,
    sortOrder: 0,
    createdByUserId: 'user_1',
    createdAt: new Date('2026-03-29T10:00:00.000Z'),
    updatedAt: new Date('2026-03-29T10:00:00.000Z'),
    ...overrides
  };
}

async function buildApp(
  userById: Map<string, TestUser | undefined>,
  listsById: Map<string, TestList | undefined>,
  itemsById: Map<string, TestItem | undefined>,
  sessions: TestSession[] = []
) {
  const app = Fastify();

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
      findFirst: async ({
        where
      }: {
        where: { id?: string; members?: { some?: { userId?: string } } };
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
      }
    },
    listItem: {
      findMany: async ({
        where,
        orderBy,
        take
      }: {
        where?: { listId?: string };
        orderBy?: { sortOrder?: 'asc' | 'desc' };
        take?: number;
      }) => {
        const listId = where?.listId;
        let items = [...itemsById.values()].filter((item): item is TestItem => Boolean(item && (!listId || item.listId === listId)));

        if (orderBy?.sortOrder === 'asc') {
          items = items.sort((left, right) => left.sortOrder - right.sortOrder);
        } else if (orderBy?.sortOrder === 'desc') {
          items = items.sort((left, right) => right.sortOrder - left.sortOrder);
        }

        return take ? items.slice(0, take) : items;
      },
      findFirst: async ({ where }: { where: { id?: string; listId?: string } }) => {
        const item = where.id ? itemsById.get(where.id) ?? null : null;

        if (!item) {
          return null;
        }

        if (where.listId && item.listId !== where.listId) {
          return null;
        }

        return item;
      },
      create: async ({
        data
      }: {
        data: {
          listId: string;
          name: string;
          quantity?: string | null;
          unit?: string | null;
          isChecked: boolean;
          sortOrder: number;
          createdByUserId: string;
        };
      }) => {
        const now = new Date('2026-03-30T10:00:00.000Z');
        const item = buildItem({
          id: `item_${itemsById.size + 1}`,
          listId: data.listId,
          name: data.name,
          quantity: data.quantity ?? null,
          unit: data.unit ?? null,
          isChecked: data.isChecked,
          sortOrder: data.sortOrder,
          createdByUserId: data.createdByUserId,
          createdAt: now,
          updatedAt: now
        });

        itemsById.set(item.id, item);
        return item;
      },
      update: async ({
        where,
        data
      }: {
        where: { id: string };
        data: { name?: string; quantity?: string | null; unit?: string | null; isChecked?: boolean };
      }) => {
        const item = itemsById.get(where.id);

        if (!item) {
          throw new Error('Item not found');
        }

        const updatedItem = {
          ...item,
          name: data.name ?? item.name,
          quantity: data.quantity === undefined ? item.quantity : data.quantity,
          unit: data.unit === undefined ? item.unit : data.unit,
          isChecked: data.isChecked ?? item.isChecked,
          updatedAt: new Date('2026-03-30T10:00:00.000Z')
        };

        itemsById.set(where.id, updatedItem);
        return updatedItem;
      },
      delete: async ({ where }: { where: { id: string } }) => {
        const item = itemsById.get(where.id);

        if (!item) {
          throw new Error('Item not found');
        }

        itemsById.delete(where.id);
        return item;
      }
    }
  };

  await app.register(sensible);
  await app.register(createItemRoutes({ prisma: prismaMock as never }));
  await app.ready();
  return app;
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

test('GET /lists/:listId/items returns items visible to the user ordered by sortOrder', async () => {
  const user = buildUser();
  const list = buildList({ memberIds: new Set([user.id]) });
  const items = new Map<string, TestItem | undefined>([
    ['item_1', buildItem({ id: 'item_1', listId: list.id, name: 'Bread', sortOrder: 2, createdByUserId: user.id })],
    ['item_2', buildItem({ id: 'item_2', listId: list.id, name: 'Butter', sortOrder: 1, createdByUserId: user.id })]
  ]);
  const { rawToken, session } = buildSessionToken(user.id);
  const app = await buildApp(new Map([[user.id, user]]), new Map([[list.id, list]]), items, [session]);

  try {
    const response = await app.inject({
      method: 'GET',
      url: `/lists/${list.id}/items`,
      headers: { authorization: `Bearer ${rawToken}` }
    });

    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json().items.map((item: { name: string }) => item.name), ['Butter', 'Bread']);
  } finally {
    await app.close();
  }
});

test('POST /lists/:listId/items creates a new item for a visible list', async () => {
  const user = buildUser();
  const list = buildList({ memberIds: new Set([user.id]) });
  const items = new Map<string, TestItem | undefined>([
    ['item_1', buildItem({ id: 'item_1', listId: list.id, sortOrder: 0, createdByUserId: user.id })]
  ]);
  const { rawToken, session } = buildSessionToken(user.id);
  const app = await buildApp(new Map([[user.id, user]]), new Map([[list.id, list]]), items, [session]);

  try {
    const response = await app.inject({
      method: 'POST',
      url: `/lists/${list.id}/items`,
      headers: { authorization: `Bearer ${rawToken}` },
      payload: { name: '  Apples  ', quantity: ' 2 ', unit: ' kg ' }
    });

    assert.equal(response.statusCode, 201);
    assert.equal(response.json().item.name, 'Apples');
    assert.equal(items.size, 2);
  } finally {
    await app.close();
  }
});

test('PATCH /lists/:listId/items/:itemId updates an item', async () => {
  const user = buildUser();
  const list = buildList({ memberIds: new Set([user.id]) });
  const item = buildItem({ id: 'item_1', listId: list.id, name: 'Milk', quantity: '1', unit: 'l', isChecked: false, createdByUserId: user.id });
  const { rawToken, session } = buildSessionToken(user.id);
  const app = await buildApp(new Map([[user.id, user]]), new Map([[list.id, list]]), new Map([[item.id, item]]), [session]);

  try {
    const response = await app.inject({
      method: 'PATCH',
      url: `/lists/${list.id}/items/${item.id}`,
      headers: { authorization: `Bearer ${rawToken}` },
      payload: { name: 'Oat milk', isChecked: true }
    });

    assert.equal(response.statusCode, 200);
    assert.equal(response.json().item.name, 'Oat milk');
    assert.equal(response.json().item.isChecked, true);
  } finally {
    await app.close();
  }
});

test('DELETE /lists/:listId/items/:itemId removes the item', async () => {
  const user = buildUser();
  const list = buildList({ memberIds: new Set([user.id]) });
  const item = buildItem({ id: 'item_1', listId: list.id, createdByUserId: user.id });
  const { rawToken, session } = buildSessionToken(user.id);
  const items = new Map<string, TestItem | undefined>([[item.id, item]]);
  const app = await buildApp(new Map([[user.id, user]]), new Map([[list.id, list]]), items, [session]);

  try {
    const response = await app.inject({
      method: 'DELETE',
      url: `/lists/${list.id}/items/${item.id}`,
      headers: { authorization: `Bearer ${rawToken}` }
    });

    assert.equal(response.statusCode, 204);
    assert.equal(items.size, 0);
  } finally {
    await app.close();
  }
});

test('GET /lists/:listId/items returns 404 for a list the user cannot access', async () => {
  const user = buildUser();
  const list = buildList({ ownerUserId: 'user_2', memberIds: new Set(['user_2']) });
  const { rawToken, session } = buildSessionToken(user.id);
  const app = await buildApp(new Map([[user.id, user]]), new Map([[list.id, list]]), new Map(), [session]);

  try {
    const response = await app.inject({
      method: 'GET',
      url: `/lists/${list.id}/items`,
      headers: { authorization: `Bearer ${rawToken}` }
    });

    assert.equal(response.statusCode, 404);
  } finally {
    await app.close();
  }
});
