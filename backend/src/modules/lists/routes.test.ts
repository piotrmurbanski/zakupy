import assert from 'node:assert/strict';
import test from 'node:test';

import type { PrismaClient } from '@prisma/client';
import Fastify from 'fastify';
import jwt from '@fastify/jwt';
import sensible from '@fastify/sensible';

import { createListRoutes } from './routes.js';

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
  listsById: Map<string, TestList | undefined>
) {
  const app = Fastify();

  const prismaMock = {
    user: {
      findUnique: async ({ where }: { where: { id: string } }) => {
        return userById.get(where.id) ?? null;
      }
    },
    shoppingList: {
      findMany: async ({ where }: { where?: { members?: { some?: { userId?: string } } } }) => {
        const userId = where?.members?.some?.userId;

        return [...listsById.values()].filter((list): list is TestList => {
          if (!list) {
            return false;
          }

          return userId ? list.memberIds.has(userId) : true;
        });
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
          members?: {
            create?: {
              userId: string;
              role: string;
            };
          };
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

        if (data.members?.create?.userId) {
          list.memberIds.add(data.members.create.userId);
        }

        listsById.set(list.id, list);
        return list;
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
        };
      }) => {
        const list = listsById.get(where.id);

        if (!list) {
          throw new Error('List not found');
        }

        const updatedList = {
          ...list,
          name: data.name ?? list.name,
          updatedAt: new Date('2026-03-30T10:00:00.000Z')
        };

        listsById.set(where.id, updatedList);
        return updatedList;
      },
      delete: async ({ where }: { where: { id: string } }) => {
        const list = listsById.get(where.id);

        if (!list) {
          throw new Error('List not found');
        }

        listsById.delete(where.id);
        return list;
      }
    }
  } as unknown as Pick<PrismaClient, 'user' | 'shoppingList'>;

  await app.register(sensible);
  await app.register(jwt, {
    secret: JWT_SECRET
  });
  await app.register(
    createListRoutes({
      prisma: prismaMock
    })
  );

  await app.ready();
  return app;
}

test('POST /lists creates a list for the authenticated user', async () => {
  const user = buildUser();
  const lists = new Map<string, TestList | undefined>();
  const app = await buildApp(new Map([[user.id, user]]), lists);
  const token = await app.jwt.sign({
    sub: user.id,
    email: user.email
  });

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/lists',
      headers: {
        authorization: `Bearer ${token}`
      },
      payload: {
        name: '  Weekend groceries  '
      }
    });

    assert.equal(response.statusCode, 201);

    const body = response.json() as {
      list: {
        id: string;
        name: string;
        ownerUserId: string;
      };
    };

    assert.equal(body.list.name, 'Weekend groceries');
    assert.equal(body.list.ownerUserId, user.id);
    assert.equal(lists.size, 1);
  } finally {
    await app.close();
  }
});

test('POST /lists rejects invalid payload', async () => {
  const user = buildUser();
  const app = await buildApp(new Map([[user.id, user]]), new Map());
  const token = await app.jwt.sign({
    sub: user.id,
    email: user.email
  });

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/lists',
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

test('GET /lists returns only lists visible to the user', async () => {
  const user = buildUser();
  const otherUser = buildUser({
    id: 'user_2',
    email: 'other@example.com'
  });
  const sharedList = buildList({
    id: 'list_1',
    name: 'Shared list',
    ownerUserId: user.id,
    memberIds: new Set([user.id, otherUser.id])
  });
  const privateList = buildList({
    id: 'list_2',
    name: 'Private list',
    ownerUserId: otherUser.id,
    memberIds: new Set([otherUser.id])
  });

  const app = await buildApp(
    new Map([
      [user.id, user],
      [otherUser.id, otherUser]
    ]),
    new Map([
      [sharedList.id, sharedList],
      [privateList.id, privateList]
    ])
  );
  const token = await app.jwt.sign({
    sub: user.id,
    email: user.email
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

    const body = response.json() as {
      items: Array<{ id: string; name: string }>;
    };

    assert.deepEqual(
      body.items.map((item) => item.name),
      ['Shared list']
    );
  } finally {
    await app.close();
  }
});

test('GET /lists/:listId returns a visible list', async () => {
  const user = buildUser();
  const list = buildList({
    id: 'list_1',
    name: 'Weekly groceries',
    ownerUserId: user.id,
    memberIds: new Set([user.id])
  });
  const app = await buildApp(new Map([[user.id, user]]), new Map([[list.id, list]]));
  const token = await app.jwt.sign({
    sub: user.id,
    email: user.email
  });

  try {
    const response = await app.inject({
      method: 'GET',
      url: `/lists/${list.id}`,
      headers: {
        authorization: `Bearer ${token}`
      }
    });

    assert.equal(response.statusCode, 200);

    const body = response.json() as {
      list: {
        id: string;
        name: string;
      };
    };

    assert.equal(body.list.id, list.id);
    assert.equal(body.list.name, list.name);
  } finally {
    await app.close();
  }
});

test('GET /lists/:listId returns 404 for a list the user cannot access', async () => {
  const user = buildUser();
  const privateList = buildList({
    id: 'list_1',
    ownerUserId: 'user_2',
    memberIds: new Set(['user_2'])
  });
  const app = await buildApp(new Map([[user.id, user]]), new Map([[privateList.id, privateList]]));
  const token = await app.jwt.sign({
    sub: user.id,
    email: user.email
  });

  try {
    const response = await app.inject({
      method: 'GET',
      url: `/lists/${privateList.id}`,
      headers: {
        authorization: `Bearer ${token}`
      }
    });

    assert.equal(response.statusCode, 404);
  } finally {
    await app.close();
  }
});

test('PATCH /lists/:listId renames owned list', async () => {
  const user = buildUser();
  const list = buildList({
    id: 'list_1',
    ownerUserId: user.id,
    memberIds: new Set([user.id])
  });
  const lists = new Map([[list.id, list]]);
  const app = await buildApp(new Map([[user.id, user]]), lists);
  const token = await app.jwt.sign({
    sub: user.id,
    email: user.email
  });

  try {
    const response = await app.inject({
      method: 'PATCH',
      url: `/lists/${list.id}`,
      headers: {
        authorization: `Bearer ${token}`
      },
      payload: {
        name: 'Updated groceries'
      }
    });

    assert.equal(response.statusCode, 200);

    const body = response.json() as {
      list: {
        name: string;
      };
    };

    assert.equal(body.list.name, 'Updated groceries');
    assert.equal(lists.get(list.id)?.name, 'Updated groceries');
  } finally {
    await app.close();
  }
});

test('PATCH /lists/:listId rejects non-owner edits', async () => {
  const owner = buildUser();
  const editor = buildUser({
    id: 'user_2',
    email: 'editor@example.com'
  });
  const list = buildList({
    id: 'list_1',
    ownerUserId: owner.id,
    memberIds: new Set([owner.id, editor.id])
  });
  const app = await buildApp(
    new Map([
      [owner.id, owner],
      [editor.id, editor]
    ]),
    new Map([[list.id, list]])
  );
  const token = await app.jwt.sign({
    sub: editor.id,
    email: editor.email
  });

  try {
    const response = await app.inject({
      method: 'PATCH',
      url: `/lists/${list.id}`,
      headers: {
        authorization: `Bearer ${token}`
      },
      payload: {
        name: 'Updated by editor'
      }
    });

    assert.equal(response.statusCode, 403);
  } finally {
    await app.close();
  }
});

test('DELETE /lists/:listId deletes owned list', async () => {
  const user = buildUser();
  const list = buildList({
    id: 'list_1',
    ownerUserId: user.id,
    memberIds: new Set([user.id])
  });
  const lists = new Map([[list.id, list]]);
  const app = await buildApp(new Map([[user.id, user]]), lists);
  const token = await app.jwt.sign({
    sub: user.id,
    email: user.email
  });

  try {
    const response = await app.inject({
      method: 'DELETE',
      url: `/lists/${list.id}`,
      headers: {
        authorization: `Bearer ${token}`
      }
    });

    assert.equal(response.statusCode, 204);
    assert.equal(lists.has(list.id), false);
  } finally {
    await app.close();
  }
});

test('DELETE /lists/:listId rejects non-owner deletes', async () => {
  const owner = buildUser();
  const editor = buildUser({
    id: 'user_2',
    email: 'editor@example.com'
  });
  const list = buildList({
    id: 'list_1',
    ownerUserId: owner.id,
    memberIds: new Set([owner.id, editor.id])
  });
  const app = await buildApp(
    new Map([
      [owner.id, owner],
      [editor.id, editor]
    ]),
    new Map([[list.id, list]])
  );
  const token = await app.jwt.sign({
    sub: editor.id,
    email: editor.email
  });

  try {
    const response = await app.inject({
      method: 'DELETE',
      url: `/lists/${list.id}`,
      headers: {
        authorization: `Bearer ${token}`
      }
    });

    assert.equal(response.statusCode, 403);
  } finally {
    await app.close();
  }
});

test('GET /lists rejects missing token', async () => {
  const user = buildUser();
  const app = await buildApp(new Map([[user.id, user]]), new Map());

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
