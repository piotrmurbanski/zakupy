import type { FastifyPluginAsync, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';

import { prisma } from '../../lib/prisma.js';
import type { UserRecord } from '../../lib/types.js';
import { authenticateRequest } from '../auth/session.js';

type ItemResponse = {
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

type ItemRecord = {
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

type ListRecord = {
  id: string;
  ownerUserId: string;
  name: string;
  createdAt: Date;
  updatedAt: Date;
};

type ItemRepository = {
  findMany(args: {
    where?: { listId?: string };
    orderBy?: { sortOrder?: 'asc' | 'desc' };
    take?: number;
  }): Promise<ItemRecord[]>;
  findFirst(args: {
    where: { id?: string; listId?: string };
  }): Promise<ItemRecord | null>;
  create(args: {
    data: {
      listId: string;
      name: string;
      quantity?: string | null;
      unit?: string | null;
      isChecked: boolean;
      sortOrder: number;
      createdByUserId: string;
    };
  }): Promise<ItemRecord>;
  update(args: {
    where: { id: string };
    data: {
      name?: string;
      quantity?: string | null;
      unit?: string | null;
      isChecked?: boolean;
    };
  }): Promise<ItemRecord>;
  delete(args: {
    where: { id: string };
  }): Promise<ItemRecord>;
};

type ListRepository = {
  findFirst(args: {
    where: {
      id?: string;
      members?: {
        some?: {
          userId?: string;
        };
      };
    };
  }): Promise<ListRecord | null>;
};

type UserRepository = {
  findUnique(args: {
    where: {
      id?: string;
      email?: string;
    };
  }): Promise<UserRecord | null>;
};

type AuthSessionRepository = {
  findFirst(args: {
    where: {
      tokenHash?: string;
      revokedAt?: null;
    };
    include?: {
      user?: boolean;
    };
  }): Promise<({ id: string; expiresAt: Date; user?: UserRecord } & Record<string, unknown>) | null>;
  update(args: {
    where: {
      id: string;
    };
    data: {
      lastUsedAt?: Date;
    };
  }): Promise<unknown>;
};

type ItemRoutesDeps = {
  prisma: {
    listItem: ItemRepository;
    shoppingList: ListRepository;
    user: UserRepository;
    authSession: AuthSessionRepository;
  };
};

const itemBodySchema = z.object({
  name: z.string().trim().min(1).max(100),
  quantity: z.union([z.string().trim().min(1).max(50), z.null()]).optional(),
  unit: z.union([z.string().trim().min(1).max(50), z.null()]).optional()
});

const updateItemBodySchema = z.object({
  name: z.string().trim().min(1).max(100).optional(),
  quantity: z.union([z.string().trim().min(1).max(50), z.null()]).optional(),
  unit: z.union([z.string().trim().min(1).max(50), z.null()]).optional(),
  isChecked: z.boolean().optional()
});

const defaultDeps = {
  prisma: prisma as unknown as ItemRoutesDeps['prisma']
};

function toItemResponse(
  item: Pick<
    ItemRecord,
    | 'id'
    | 'listId'
    | 'name'
    | 'quantity'
    | 'unit'
    | 'isChecked'
    | 'sortOrder'
    | 'createdByUserId'
    | 'createdAt'
    | 'updatedAt'
  >
): ItemResponse {
  return {
    id: item.id,
    listId: item.listId,
    name: item.name,
    quantity: item.quantity,
    unit: item.unit,
    isChecked: item.isChecked,
    sortOrder: item.sortOrder,
    createdByUserId: item.createdByUserId,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt
  };
}

function parseBody<T>(schema: z.ZodType<T>, body: unknown) {
  const result = schema.safeParse(body);

  if (!result.success) {
    return null;
  }

  return result.data;
}

async function findVisibleList(deps: ItemRoutesDeps, userId: string, listId: string) {
  return deps.prisma.shoppingList.findFirst({
    where: {
      id: listId,
      members: {
        some: {
          userId
        }
      }
    }
  });
}

async function ensureVisibleList(
  deps: ItemRoutesDeps,
  userId: string,
  listId: string,
  reply: FastifyReply
) {
  const list = await findVisibleList(deps, userId, listId);

  if (!list) {
    reply.notFound('List not found');
    return null;
  }

  return list;
}

async function findVisibleItem(deps: ItemRoutesDeps, listId: string, itemId: string) {
  return deps.prisma.listItem.findFirst({
    where: {
      id: itemId,
      listId
    }
  });
}

async function getNextSortOrder(deps: ItemRoutesDeps, listId: string) {
  const [latestItem] = await deps.prisma.listItem.findMany({
    where: {
      listId
    },
    orderBy: {
      sortOrder: 'desc'
    },
    take: 1
  });

  return (latestItem?.sortOrder ?? -1) + 1;
}

export function createItemRoutes(deps: ItemRoutesDeps = defaultDeps): FastifyPluginAsync {
  return async (app) => {
    app.get('/lists/:listId/items', async (request, reply) => {
      const user = await authenticateRequest(deps.prisma, request, reply);

      if (!user) {
        return;
      }

      const { listId } = request.params as { listId: string };
      const list = await ensureVisibleList(deps, user.id, listId, reply);

      if (!list) {
        return;
      }

      const items = await deps.prisma.listItem.findMany({
        where: {
          listId
        },
        orderBy: {
          sortOrder: 'asc'
        }
      });

      return {
        items: items.map(toItemResponse)
      };
    });

    app.post('/lists/:listId/items', async (request, reply) => {
      const user = await authenticateRequest(deps.prisma, request, reply);

      if (!user) {
        return;
      }

      const { listId } = request.params as { listId: string };
      const list = await ensureVisibleList(deps, user.id, listId, reply);

      if (!list) {
        return;
      }

      const body = parseBody(itemBodySchema, request.body);

      if (!body) {
        return reply.badRequest('Invalid request body');
      }

      const sortOrder = await getNextSortOrder(deps, listId);
      const item = await deps.prisma.listItem.create({
        data: {
          listId,
          name: body.name,
          quantity: body.quantity ?? null,
          unit: body.unit ?? null,
          isChecked: false,
          sortOrder,
          createdByUserId: user.id
        }
      });

      return reply.code(201).send({
        item: toItemResponse(item)
      });
    });

    app.patch('/lists/:listId/items/:itemId', async (request, reply) => {
      const user = await authenticateRequest(deps.prisma, request, reply);

      if (!user) {
        return;
      }

      const { listId, itemId } = request.params as { listId: string; itemId: string };
      const list = await ensureVisibleList(deps, user.id, listId, reply);

      if (!list) {
        return;
      }

      const body = parseBody(updateItemBodySchema, request.body);

      if (!body) {
        return reply.badRequest('Invalid request body');
      }

      if (Object.keys(body).length === 0) {
        return reply.badRequest('Invalid request body');
      }

      const existingItem = await findVisibleItem(deps, listId, itemId);

      if (!existingItem) {
        return reply.notFound('Item not found');
      }

      const item = await deps.prisma.listItem.update({
        where: {
          id: existingItem.id
        },
        data: {
          name: body.name,
          quantity: body.quantity,
          unit: body.unit,
          isChecked: body.isChecked
        }
      });

      return {
        item: toItemResponse(item)
      };
    });

    app.delete('/lists/:listId/items/:itemId', async (request, reply) => {
      const user = await authenticateRequest(deps.prisma, request, reply);

      if (!user) {
        return;
      }

      const { listId, itemId } = request.params as { listId: string; itemId: string };
      const list = await ensureVisibleList(deps, user.id, listId, reply);

      if (!list) {
        return;
      }

      const existingItem = await findVisibleItem(deps, listId, itemId);

      if (!existingItem) {
        return reply.notFound('Item not found');
      }

      await deps.prisma.listItem.delete({
        where: {
          id: existingItem.id
        }
      });

      return reply.code(204).send();
    });
  };
}

export const itemRoutes = createItemRoutes();
