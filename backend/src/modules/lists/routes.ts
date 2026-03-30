import type { PrismaClient, ShoppingList, User } from '@prisma/client';
import type { FastifyPluginAsync, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';

import { prisma } from '../../lib/prisma.js';

type JwtUserPayload = {
  sub: string;
  email: string;
};

type ListResponse = {
  id: string;
  name: string;
  ownerUserId: string;
  createdAt: Date;
  updatedAt: Date;
};

type ListRepository = Pick<PrismaClient['shoppingList'], 'findMany' | 'findFirst' | 'create' | 'update' | 'delete'>;
type UserRepository = Pick<PrismaClient['user'], 'findUnique'>;

type ListRoutesDeps = {
  prisma: {
    shoppingList: ListRepository;
    user: UserRepository;
  };
};

const listBodySchema = z.object({
  name: z.string().trim().min(1).max(100)
});

const defaultDeps = {
  prisma
} satisfies ListRoutesDeps;

function toListResponse(list: Pick<ShoppingList, 'id' | 'name' | 'ownerUserId' | 'createdAt' | 'updatedAt'>): ListResponse {
  return {
    id: list.id,
    name: list.name,
    ownerUserId: list.ownerUserId,
    createdAt: list.createdAt,
    updatedAt: list.updatedAt
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
  deps: ListRoutesDeps,
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

async function findVisibleList(deps: ListRoutesDeps, userId: string, listId: string) {
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

export function createListRoutes(deps: ListRoutesDeps = defaultDeps): FastifyPluginAsync {
  return async (app) => {
    app.get('/lists', async (request, reply) => {
      const user = await authenticateRequest(deps, request, reply);

      if (!user) {
        return;
      }

      const lists = await deps.prisma.shoppingList.findMany({
        where: {
          members: {
            some: {
              userId: user.id
            }
          }
        },
        orderBy: {
          updatedAt: 'desc'
        }
      });

      return {
        items: lists.map(toListResponse)
      };
    });

    app.post('/lists', async (request, reply) => {
      const user = await authenticateRequest(deps, request, reply);

      if (!user) {
        return;
      }

      const body = parseBody(listBodySchema, request.body);

      if (!body) {
        return reply.badRequest('Invalid request body');
      }

      const list = await deps.prisma.shoppingList.create({
        data: {
          name: body.name,
          ownerUserId: user.id,
          members: {
            create: {
              userId: user.id,
              role: 'owner'
            }
          }
        }
      });

      return reply.code(201).send({
        list: toListResponse(list)
      });
    });

    app.get('/lists/:listId', async (request, reply) => {
      const user = await authenticateRequest(deps, request, reply);

      if (!user) {
        return;
      }

      const { listId } = request.params as { listId: string };
      const list = await findVisibleList(deps, user.id, listId);

      if (!list) {
        return reply.notFound('List not found');
      }

      return {
        list: toListResponse(list)
      };
    });

    app.patch('/lists/:listId', async (request, reply) => {
      const user = await authenticateRequest(deps, request, reply);

      if (!user) {
        return;
      }

      const { listId } = request.params as { listId: string };
      const body = parseBody(listBodySchema, request.body);

      if (!body) {
        return reply.badRequest('Invalid request body');
      }

      const list = await findVisibleList(deps, user.id, listId);

      if (!list) {
        return reply.notFound('List not found');
      }

      if (list.ownerUserId !== user.id) {
        return reply.forbidden('Only the owner can modify this list');
      }

      const updatedList = await deps.prisma.shoppingList.update({
        where: {
          id: list.id
        },
        data: {
          name: body.name
        }
      });

      return {
        list: toListResponse(updatedList)
      };
    });

    app.delete('/lists/:listId', async (request, reply) => {
      const user = await authenticateRequest(deps, request, reply);

      if (!user) {
        return;
      }

      const { listId } = request.params as { listId: string };
      const list = await findVisibleList(deps, user.id, listId);

      if (!list) {
        return reply.notFound('List not found');
      }

      if (list.ownerUserId !== user.id) {
        return reply.forbidden('Only the owner can delete this list');
      }

      await deps.prisma.shoppingList.delete({
        where: {
          id: list.id
        }
      });

      return reply.code(204).send();
    });
  };
}

export const listRoutes = createListRoutes();
