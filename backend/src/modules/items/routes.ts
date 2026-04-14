import type { FastifyPluginAsync, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';

import { prisma } from '../../lib/prisma.js';
import type { UserRecord } from '../../lib/types.js';
import { authenticateRequest } from '../auth/session.js';
import { defaultItemIconKey, normalizeItemIconKey } from './item_icons.js';

type ItemResponse = {
  id: string;
  listId: string;
  name: string;
  quantity: number;
  comment: string | null;
  isChecked: boolean;
  iconKey: string;
  sortOrder: number;
  createdByUserId: string;
  createdAt: Date;
  updatedAt: Date;
};

type ItemRecord = {
  id: string;
  listId: string;
  name: string;
  quantity: number;
  comment: string | null;
  isChecked: boolean;
  iconKey: string;
  sortOrder: number;
  createdByUserId: string;
  createdAt: Date;
  updatedAt: Date;
};

type ItemSuggestionResponse = {
  id: string;
  name: string;
  comment: string | null;
  iconKey: string;
  usageCount: number;
  lastUsedAt: Date;
};

type ItemSuggestionRecord = {
  id: string;
  userId: string;
  name: string;
  normalizedName: string;
  comment: string | null;
  normalizedComment: string;
  iconKey: string;
  usageCount: number;
  lastUsedAt: Date;
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
        quantity: number;
        comment?: string | null;
        isChecked: boolean;
        iconKey: string;
        sortOrder: number;
        createdByUserId: string;
      };
    }): Promise<ItemRecord>;
    update(args: {
      where: { id: string };
      data: {
        name?: string;
        quantity?: number;
        comment?: string | null;
        isChecked?: boolean;
        iconKey?: string;
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
    itemSuggestion: {
      findMany(args: {
        where: { userId: string };
        orderBy: Array<{ usageCount?: 'asc' | 'desc' } | { lastUsedAt?: 'asc' | 'desc' } | { name?: 'asc' | 'desc' }>;
        take: number;
      }): Promise<ItemSuggestionRecord[]>;
      findFirst(args: {
        where: {
          userId: string;
          normalizedName: string;
          normalizedComment: string;
        };
      }): Promise<ItemSuggestionRecord | null>;
      create(args: {
        data: {
          userId: string;
          name: string;
          normalizedName: string;
          comment?: string | null;
          normalizedComment?: string;
          iconKey: string;
          usageCount: number;
          lastUsedAt: Date;
        };
      }): Promise<ItemSuggestionRecord>;
      update(args: {
        where: { id: string };
        data: {
          name?: string;
          comment?: string | null;
          iconKey?: string;
          usageCount?: { increment: number };
          lastUsedAt?: Date;
        };
      }): Promise<ItemSuggestionRecord>;
    };
    shoppingList: ListRepository;
    user: UserRepository;
    authSession: AuthSessionRepository;
  };
};

const itemBodySchema = z.object({
  name: z.string().trim().min(1).max(100),
  quantity: z.coerce.number().int().min(1).max(999).optional(),
  comment: z.union([z.string().trim().min(1).max(140), z.null()]).optional(),
  iconKey: z.string().trim().min(1).max(50).optional()
});

const updateItemBodySchema = z.object({
  name: z.string().trim().min(1).max(100).optional(),
  quantity: z.coerce.number().int().min(1).max(999).optional(),
  comment: z.union([z.string().trim().min(1).max(140), z.null()]).optional(),
  isChecked: z.boolean().optional(),
  iconKey: z.string().trim().min(1).max(50).optional()
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
    | 'comment'
    | 'isChecked'
    | 'iconKey'
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
    comment: item.comment,
    isChecked: item.isChecked,
    iconKey: normalizeItemIconKey(item.iconKey),
    sortOrder: item.sortOrder,
    createdByUserId: item.createdByUserId,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt
  };
}

function toSuggestionResponse(suggestion: ItemSuggestionRecord): ItemSuggestionResponse {
  return {
    id: suggestion.id,
    name: suggestion.name,
    comment: suggestion.comment,
    iconKey: normalizeItemIconKey(suggestion.iconKey),
    usageCount: suggestion.usageCount,
    lastUsedAt: suggestion.lastUsedAt
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

function normalizeSuggestionPart(value: string | null | undefined) {
  const trimmed = value?.trim() ?? '';
  return trimmed.length == 0 ? null : trimmed.toLowerCase();
}

async function recordSuggestionUsage(
  deps: ItemRoutesDeps,
  userId: string,
  {
    name,
    comment,
    iconKey,
    incrementBy
  }: {
    name: string;
    comment?: string | null;
    iconKey: string;
    incrementBy: number;
  }
) {
  const normalizedName = normalizeSuggestionPart(name);
  const normalizedComment = normalizeSuggestionPart(comment) ?? '';

  if (normalizedName == null) {
    return;
  }

  const now = new Date();
  const existingSuggestion = await deps.prisma.itemSuggestion.findFirst({
    where: {
      userId,
      normalizedName,
      normalizedComment
    }
  });

  if (existingSuggestion) {
    await deps.prisma.itemSuggestion.update({
      where: {
        id: existingSuggestion.id
      },
      data: {
        name: name.trim(),
        comment: comment?.trim() ?? null,
        iconKey,
        ...(incrementBy > 0
          ? {
              usageCount: {
                increment: incrementBy
              },
              lastUsedAt: now
            }
          : {
              lastUsedAt: now
            })
      }
    });
    return;
  }

  if (incrementBy <= 0) {
    return;
  }

  await deps.prisma.itemSuggestion.create({
    data: {
      userId,
      name: name.trim(),
      normalizedName,
      comment: comment?.trim() ?? null,
      normalizedComment,
      iconKey,
      usageCount: incrementBy,
      lastUsedAt: now
    }
  });
}

export function createItemRoutes(deps: ItemRoutesDeps = defaultDeps): FastifyPluginAsync {
  return async (app) => {
    app.get('/items/suggestions', async (request, reply) => {
      const user = await authenticateRequest(deps.prisma, request, reply);

      if (!user) {
        return;
      }

      const suggestions = await deps.prisma.itemSuggestion.findMany({
        where: {
          userId: user.id
        },
        orderBy: [{ usageCount: 'desc' }, { lastUsedAt: 'desc' }, { name: 'asc' }],
        take: 12
      });

      return {
        items: suggestions.map(toSuggestionResponse)
      };
    });

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
          quantity: body.quantity ?? 1,
          comment: body.comment ?? null,
          isChecked: false,
          iconKey: normalizeItemIconKey(body.iconKey ?? defaultItemIconKey),
          sortOrder,
          createdByUserId: user.id
        }
      });

      await recordSuggestionUsage(deps, user.id, {
        name: item.name,
        comment: item.comment,
        iconKey: item.iconKey,
        incrementBy: item.quantity
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

      const nextName = body.name ?? existingItem.name;
      const nextComment = body.comment === undefined ? existingItem.comment : body.comment;
      const nextQuantity = body.quantity ?? existingItem.quantity;

      const item = await deps.prisma.listItem.update({
        where: {
          id: existingItem.id
        },
        data: {
          name: body.name,
          quantity: body.quantity,
          comment: body.comment,
          isChecked: body.isChecked,
          iconKey: body.iconKey ? normalizeItemIconKey(body.iconKey) : undefined
        }
      });

      await recordSuggestionUsage(deps, user.id, {
        name: nextName,
        comment: nextComment,
        iconKey: item.iconKey,
        incrementBy: Math.max(nextQuantity - existingItem.quantity, 0)
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
