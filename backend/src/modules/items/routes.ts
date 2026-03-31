import type { ListItem, PrismaClient, ShoppingList, User } from '@prisma/client';
import type { FastifyPluginAsync, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';

import { prisma } from '../../lib/prisma.js';

type JwtUserPayload = {
  sub: string;
  email: string;
};

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

type ItemRepository = Pick<PrismaClient['listItem'], 'findMany' | 'findFirst' | 'create' | 'update' | 'delete'>;
type ListRepository = Pick<PrismaClient['shoppingList'], 'findFirst'>;
type UserRepository = Pick<PrismaClient['user'], 'findUnique'>;

type ItemRoutesDeps = {
  prisma: {
    listItem: ItemRepository;
    shoppingList: ListRepository;
    user: UserRepository;
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
  prisma
} satisfies ItemRoutesDeps;

function toItemResponse(
  item: Pick<
    ListItem,
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

async function authenticateRequest(
  deps: ItemRoutesDeps,
  request: FastifyRequest,
  reply: FastifyReply
): Promise<Pick<User, 'id' | 'email' | 'displayName' | 'createdAt' | 'updatedAt'> | null> {
  const payload = await request.jwtVerify<JwtUserPayload>();
  const user = await deps.prisma.user.findUnique({
    where: {
      id: payload.sub
    }
  });

  if (!user) {
    reply.unauthorized('User not found');
    return null;
  }

  return user;
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
      const user = await authenticateRequest(deps, request, reply);

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
      const user = await authenticateRequest(deps, request, reply);

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
      const user = await authenticateRequest(deps, request, reply);

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
      const user = await authenticateRequest(deps, request, reply);

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
