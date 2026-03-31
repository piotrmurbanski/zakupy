import type { ListMember, PrismaClient, ShoppingList, User } from '@prisma/client';
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

type MemberResponse = {
  id: string;
  listId: string;
  userId: string;
  role: string;
  createdAt: Date;
  updatedAt: Date;
  user: {
    id: string;
    email: string;
    displayName: string;
  };
};

type ListRepository = Pick<PrismaClient['shoppingList'], 'findMany' | 'findFirst' | 'create' | 'update' | 'delete'>;
type ListMemberRepository = Pick<PrismaClient['listMember'], 'findUnique' | 'create' | 'delete'>;
type UserRepository = Pick<PrismaClient['user'], 'findUnique'>;

type ListRoutesDeps = {
  prisma: {
    shoppingList: ListRepository;
    listMember: ListMemberRepository;
    user: UserRepository;
  };
};

const listBodySchema = z.object({
  name: z.string().trim().min(1).max(100)
});

const listMemberBodySchema = z.object({
  email: z.string().trim().email().transform((value) => value.toLowerCase())
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

function toMemberResponse(
  member: Pick<ListMember, 'id' | 'listId' | 'userId' | 'role' | 'createdAt' | 'updatedAt'> & {
    user: Pick<User, 'id' | 'email' | 'displayName'>;
  }
): MemberResponse {
  return {
    id: member.id,
    listId: member.listId,
    userId: member.userId,
    role: member.role,
    createdAt: member.createdAt,
    updatedAt: member.updatedAt,
    user: {
      id: member.user.id,
      email: member.user.email,
      displayName: member.user.displayName
    }
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

async function ensureOwnedVisibleList(
  deps: ListRoutesDeps,
  userId: string,
  listId: string,
  reply: FastifyReply
) {
  const list = await findVisibleList(deps, userId, listId);

  if (!list) {
    reply.notFound('List not found');
    return null;
  }

  if (list.ownerUserId !== userId) {
    reply.forbidden('Only the owner can manage list members');
    return null;
  }

  return list;
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

    app.post('/lists/:listId/members', async (request, reply) => {
      const user = await authenticateRequest(deps, request, reply);

      if (!user) {
        return;
      }

      const { listId } = request.params as { listId: string };
      const list = await ensureOwnedVisibleList(deps, user.id, listId, reply);

      if (!list) {
        return;
      }

      const body = parseBody(listMemberBodySchema, request.body);

      if (!body) {
        return reply.badRequest('Invalid request body');
      }

      const invitedUser = await deps.prisma.user.findUnique({
        where: {
          email: body.email
        }
      });

      if (!invitedUser) {
        return reply.notFound('User not found');
      }

      const existingMember = await deps.prisma.listMember.findUnique({
        where: {
          listId_userId: {
            listId,
            userId: invitedUser.id
          }
        }
      });

      if (existingMember) {
        return reply.conflict('User is already a member of this list');
      }

      const member = await deps.prisma.listMember.create({
        data: {
          listId,
          userId: invitedUser.id,
          role: 'editor'
        },
        include: {
          user: true
        }
      });

      return reply.code(201).send({
        member: toMemberResponse(member)
      });
    });

    app.delete('/lists/:listId/members/:userId', async (request, reply) => {
      const user = await authenticateRequest(deps, request, reply);

      if (!user) {
        return;
      }

      const { listId, userId } = request.params as { listId: string; userId: string };
      const list = await ensureOwnedVisibleList(deps, user.id, listId, reply);

      if (!list) {
        return;
      }

      if (userId === list.ownerUserId) {
        return reply.badRequest('Owner cannot be removed from the list');
      }

      const existingMember = await deps.prisma.listMember.findUnique({
        where: {
          listId_userId: {
            listId,
            userId
          }
        }
      });

      if (!existingMember) {
        return reply.notFound('Member not found');
      }

      await deps.prisma.listMember.delete({
        where: {
          listId_userId: {
            listId,
            userId
          }
        }
      });

      return reply.code(204).send();
    });
  };
}

export const listRoutes = createListRoutes();
