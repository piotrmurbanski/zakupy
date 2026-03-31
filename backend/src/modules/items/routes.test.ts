import assert from 'node:assert/strict';
import test from 'node:test';

import type { PrismaClient } from '@prisma/client';
import Fastify from 'fastify';
import jwt from '@fastify/jwt';
import sensible from '@fastify/sensible';

import { createItemRoutes } from './routes.js';

const JWT_SECRET = 'test-secret';

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
  itemsById: Map<string, TestItem | undefined>
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
    shoppingList: {
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
        let items = [...itemsById.values()].filter((item): item is TestItem => {
          if (!item) {
            return false;
          }

          return listId ? item.listId === listId : true;
        });

        if (orderBy?.sortOrder === 'asc') {
          items = items.sort((left, right) => left.sortOrder - right.sortOrder);
        } else if (orderBy?.sortOrder === 'desc') {
          items = items.sort((left, right) => right.sortOrder - left.sortOrder);
        }

        if (take) {
          items = items.slice(0, take);
        }

        return items;
      },
      findFirst: async ({
        where
      }: {
        where: {
          id?: string;
          listId?: string;
        };
      }) => {
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
        where: {
          id: string;
        };
        data: {
          name?: string;
          quantity?: string | null;
          unit?: string | null;
          isChecked?: boolean;
        };
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
  } as unknown as Pick<PrismaClient, 'user' | 'shoppingList' | 'listItem'>;

  await app.register(sensible);
  await app.register(jwt, {
    secret: JWT_SECRET
  });
  await app.register(
    createItemRoutes({
      prisma: prismaMock
    })
  );

  await app.ready();
  return app;
}

test('GET /lists/:listId/items returns items visible to the user ordered by sortOrder', async () => {
  const user = buildUser();
  const list = buildList({
    memberIds: new Set([user.id])
  });
  const items = new Map<string, TestItem | undefined>([
    [
      'item_1',
      buildItem({
        id: 'item_1',
        listId: list.id,
        name: 'Bread',
        sortOrder: 2,
        createdByUserId: user.id
      })
    ],
    [
      'item_2',
      buildItem({
        id: 'item_2',
        listId: list.id,
        name: 'Butter',
        sortOrder: 1,
        createdByUserId: user.id
      })
    ]
  ]);
  const app = await buildApp(new Map([[user.id, user]]), new Map([[list.id, list]]), items);
  const token = await app.jwt.sign({
    sub: user.id,
    email: user.email
  });

  try {
    const response = await app.inject({
      method: 'GET',
      url: `/lists/${list.id}/items`,
      headers: {
        authorization: `Bearer ${token}`
      }
    });

    assert.equal(response.statusCode, 200);

    const body = response.json() as {
      items: Array<{ id: string; name: string; sortOrder: number }>;
    };

    assert.deepEqual(
      body.items.map((item) => item.name),
      ['Butter', 'Bread']
    );
    assert.deepEqual(
      body.items.map((item) => item.sortOrder),
      [1, 2]
    );
  } finally {
    await app.close();
  }
});

test('GET /lists/:listId/items returns 404 for a list the user cannot access', async () => {
  const user = buildUser();
  const list = buildList({
    ownerUserId: 'user_2',
    memberIds: new Set(['user_2'])
  });
  const app = await buildApp(new Map([[user.id, user]]), new Map([[list.id, list]]), new Map());
  const token = await app.jwt.sign({
    sub: user.id,
    email: user.email
  });

  try {
    const response = await app.inject({
      method: 'GET',
      url: `/lists/${list.id}/items`,
      headers: {
        authorization: `Bearer ${token}`
      }
    });

    assert.equal(response.statusCode, 404);
  } finally {
    await app.close();
  }
});

test('POST /lists/:listId/items creates a new item for a visible list', async () => {
  const user = buildUser();
  const list = buildList({
    memberIds: new Set([user.id])
  });
  const items = new Map<string, TestItem | undefined>([
    [
      'item_1',
      buildItem({
        id: 'item_1',
        listId: list.id,
        sortOrder: 0,
        createdByUserId: user.id
      })
    ]
  ]);
  const app = await buildApp(new Map([[user.id, user]]), new Map([[list.id, list]]), items);
  const token = await app.jwt.sign({
    sub: user.id,
    email: user.email
  });

  try {
    const response = await app.inject({
      method: 'POST',
      url: `/lists/${list.id}/items`,
      headers: {
        authorization: `Bearer ${token}`
      },
      payload: {
        name: '  Apples  ',
        quantity: ' 2 ',
        unit: ' kg '
      }
    });

    assert.equal(response.statusCode, 201);

    const body = response.json() as {
      item: {
        name: string;
        quantity: string | null;
        unit: string | null;
        isChecked: boolean;
        sortOrder: number;
        createdByUserId: string;
      };
    };

    assert.equal(body.item.name, 'Apples');
    assert.equal(body.item.quantity, '2');
    assert.equal(body.item.unit, 'kg');
    assert.equal(body.item.isChecked, false);
    assert.equal(body.item.sortOrder, 1);
    assert.equal(body.item.createdByUserId, user.id);
    assert.equal(items.size, 2);
  } finally {
    await app.close();
  }
});

test('POST /lists/:listId/items rejects invalid payload', async () => {
  const user = buildUser();
  const list = buildList({
    memberIds: new Set([user.id])
  });
  const app = await buildApp(new Map([[user.id, user]]), new Map([[list.id, list]]), new Map());
  const token = await app.jwt.sign({
    sub: user.id,
    email: user.email
  });

  try {
    const response = await app.inject({
      method: 'POST',
      url: `/lists/${list.id}/items`,
      headers: {
        authorization: `Bearer ${token}`
      },
      payload: {
        name: ' '
      }
    });

    assert.equal(response.statusCode, 400);
  } finally {
    await app.close();
  }
});

test('PATCH /lists/:listId/items/:itemId updates an item', async () => {
  const user = buildUser();
  const list = buildList({
    memberIds: new Set([user.id])
  });
  const item = buildItem({
    id: 'item_1',
    listId: list.id,
    name: 'Milk',
    quantity: '1',
    unit: 'l',
    isChecked: false,
    createdByUserId: user.id
  });
  const items = new Map<string, TestItem | undefined>([[item.id, item]]);
  const app = await buildApp(new Map([[user.id, user]]), new Map([[list.id, list]]), items);
  const token = await app.jwt.sign({
    sub: user.id,
    email: user.email
  });

  try {
    const response = await app.inject({
      method: 'PATCH',
      url: `/lists/${list.id}/items/${item.id}`,
      headers: {
        authorization: `Bearer ${token}`
      },
      payload: {
        name: 'Oat milk',
        isChecked: true
      }
    });

    assert.equal(response.statusCode, 200);

    const body = response.json() as {
      item: {
        name: string;
        quantity: string | null;
        unit: string | null;
        isChecked: boolean;
      };
    };

    assert.equal(body.item.name, 'Oat milk');
    assert.equal(body.item.quantity, '1');
    assert.equal(body.item.unit, 'l');
    assert.equal(body.item.isChecked, true);
  } finally {
    await app.close();
  }
});

test('PATCH /lists/:listId/items/:itemId rejects empty payload', async () => {
  const user = buildUser();
  const list = buildList({
    memberIds: new Set([user.id])
  });
  const item = buildItem({
    id: 'item_1',
    listId: list.id,
    createdByUserId: user.id
  });
  const app = await buildApp(new Map([[user.id, user]]), new Map([[list.id, list]]), new Map([[item.id, item]]));
  const token = await app.jwt.sign({
    sub: user.id,
    email: user.email
  });

  try {
    const response = await app.inject({
      method: 'PATCH',
      url: `/lists/${list.id}/items/${item.id}`,
      headers: {
        authorization: `Bearer ${token}`
      },
      payload: {}
    });

    assert.equal(response.statusCode, 400);
  } finally {
    await app.close();
  }
});

test('DELETE /lists/:listId/items/:itemId removes the item', async () => {
  const user = buildUser();
  const list = buildList({
    memberIds: new Set([user.id])
  });
  const item = buildItem({
    id: 'item_1',
    listId: list.id,
    createdByUserId: user.id
  });
  const items = new Map<string, TestItem | undefined>([[item.id, item]]);
  const app = await buildApp(new Map([[user.id, user]]), new Map([[list.id, list]]), items);
  const token = await app.jwt.sign({
    sub: user.id,
    email: user.email
  });

  try {
    const response = await app.inject({
      method: 'DELETE',
      url: `/lists/${list.id}/items/${item.id}`,
      headers: {
        authorization: `Bearer ${token}`
      }
    });

    assert.equal(response.statusCode, 204);
    assert.equal(items.size, 0);
  } finally {
    await app.close();
  }
});

test('DELETE /lists/:listId/items/:itemId returns 404 for a missing item', async () => {
  const user = buildUser();
  const list = buildList({
    memberIds: new Set([user.id])
  });
  const app = await buildApp(new Map([[user.id, user]]), new Map([[list.id, list]]), new Map());
  const token = await app.jwt.sign({
    sub: user.id,
    email: user.email
  });

  try {
    const response = await app.inject({
      method: 'DELETE',
      url: `/lists/${list.id}/items/missing-item`,
      headers: {
        authorization: `Bearer ${token}`
      }
    });

    assert.equal(response.statusCode, 404);
  } finally {
    await app.close();
  }
});
