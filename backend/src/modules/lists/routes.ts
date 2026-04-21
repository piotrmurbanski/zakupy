import type { FastifyPluginAsync, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';

import { prisma } from '../../lib/prisma.js';
import type { InvitationRecord, UserRecord } from '../../lib/types.js';
import { authenticateRequest, normalizeEmail } from '../auth/session.js';

type ListResponse = {
  id: string;
  name: string;
  plannedFor: Date | null;
  ownerUserId: string;
  archivedAt: Date | null;
  isArchived: boolean;
  createdAt: Date;
  updatedAt: Date;
};

type ListDetailResponse = {
  list: ListResponse;
  sharing?: SharingResponse;
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
    phoneNumber: string | null;
    whatsappEligible: boolean;
  };
};

type InvitationResponse = {
  id: string;
  listId: string;
  email: string;
  role: string;
  status: 'pending';
  createdAt: Date;
  updatedAt: Date;
};

type SharingResponse = {
  memberContacts: MemberResponse[];
  pendingInvitations: InvitationResponse[];
};

type ListRecord = {
  id: string;
  name: string;
  plannedFor: Date | null;
  ownerUserId: string;
  archivedAt: Date | null;
  archivedByUserId: string | null;
  createdAt: Date;
  updatedAt: Date;
};

type MemberRecord = {
  id: string;
  listId: string;
  userId: string;
  role: string;
  createdAt: Date;
  updatedAt: Date;
};

type ListRepository = {
  findMany(args: {
    where?: {
      members?: {
        some?: {
          userId?: string;
        };
      };
      archivedAt?: Date | null;
    };
    orderBy?: {
      updatedAt: 'asc' | 'desc';
    };
  }): Promise<ListRecord[]>;
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
  create(args: {
    data: {
      name: string;
      plannedFor?: Date | null;
      ownerUserId: string;
      members?: {
        create?: {
          userId: string;
          role: 'owner' | 'editor';
        };
      };
    };
  }): Promise<ListRecord>;
  update(args: {
    where: {
      id: string;
    };
    data: {
      name?: string;
      plannedFor?: Date | null;
      archivedAt?: Date | null;
      archivedByUserId?: string | null;
    };
  }): Promise<ListRecord>;
  delete(args: {
    where: {
      id: string;
    };
  }): Promise<ListRecord>;
};

type ListMemberRepository = {
  findUnique(args: {
    where: {
      listId_userId: {
        listId: string;
        userId: string;
      };
    };
  }): Promise<MemberRecord | null>;
  create(args: {
    data: {
      listId: string;
      userId: string;
      role: 'owner' | 'editor';
    };
    include?: {
      user?: boolean;
    };
  }): Promise<MemberRecord & { user?: Pick<UserRecord, 'id' | 'email' | 'displayName' | 'phoneNumber'> }>;
  findMany(args: {
    where: {
      listId: string;
    };
    include?: {
      user?: boolean;
    };
  }): Promise<Array<MemberRecord & { user?: Pick<UserRecord, 'id' | 'email' | 'displayName' | 'phoneNumber'> }>>;
  delete(args: {
    where: {
      listId_userId: {
        listId: string;
        userId: string;
      };
    };
  }): Promise<MemberRecord>;
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

type InvitationRepository = {
  findUnique(args: {
    where: {
      listId_email: {
        listId: string;
        email: string;
      };
    };
  }): Promise<InvitationRecord | null>;
  create(args: {
    data: {
      listId: string;
      email: string;
      role: 'owner' | 'editor';
      invitedByUserId: string;
    };
  }): Promise<InvitationRecord>;
  findMany(args: {
    where: {
      listId: string;
      claimedAt?: null;
    };
  }): Promise<InvitationRecord[]>;
};

type ListRoutesDeps = {
  prisma: {
    shoppingList: ListRepository;
    listMember: ListMemberRepository;
    user: UserRepository;
    authSession: AuthSessionRepository;
    listInvitation: InvitationRepository;
  };
};

const listBodySchema = z.object({
  name: z.string().trim().min(1).max(100),
  plannedFor: z
    .string()
    .datetime({ offset: true })
    .transform((value) => new Date(value))
    .nullable()
    .optional(),
});

const listMemberBodySchema = z.object({
  email: z.string().trim().email().transform((value) => value.toLowerCase())
});

const defaultDeps: ListRoutesDeps = {
  prisma: prisma as unknown as ListRoutesDeps['prisma'],
};

function toListResponse(
  list: Pick<
    ListRecord,
    'id' | 'name' | 'plannedFor' | 'ownerUserId' | 'archivedAt' | 'createdAt' | 'updatedAt'
  >,
): ListResponse {
  return {
    id: list.id,
    name: list.name,
    plannedFor: list.plannedFor ?? null,
    ownerUserId: list.ownerUserId,
    archivedAt: list.archivedAt ?? null,
    isArchived: list.archivedAt != null,
    createdAt: list.createdAt,
    updatedAt: list.updatedAt
  };
}

function toMemberResponse(
  member: Pick<MemberRecord, 'id' | 'listId' | 'userId' | 'role' | 'createdAt' | 'updatedAt'> & {
    user: Pick<UserRecord, 'id' | 'email' | 'displayName' | 'phoneNumber'>;
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
      displayName: member.user.displayName,
      phoneNumber: member.user.phoneNumber,
      whatsappEligible: member.user.phoneNumber != null
    }
  };
}

function toInvitationResponse(invitation: Pick<InvitationRecord, 'id' | 'listId' | 'email' | 'role' | 'createdAt' | 'updatedAt'>): InvitationResponse {
  return {
    id: invitation.id,
    listId: invitation.listId,
    email: invitation.email,
    role: invitation.role,
    status: 'pending',
    createdAt: invitation.createdAt,
    updatedAt: invitation.updatedAt
  };
}

function parseBody<TSchema extends z.ZodTypeAny>(
  schema: TSchema,
  body: unknown,
): z.output<TSchema> | null {
  const result = schema.safeParse(body);

  if (!result.success) {
    return null;
  }

  return result.data;
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

function parseIncludeArchived(value: unknown) {
  return value === true || value === 'true' || value === '1' || value === 1;
}

async function buildOwnerSharingResponse(
  deps: ListRoutesDeps,
  listId: string,
  ownerUserId: string,
): Promise<SharingResponse> {
  const [members, invitations] = await Promise.all([
    deps.prisma.listMember.findMany({
      where: {
        listId
      },
      include: {
        user: true
      }
    }),
    deps.prisma.listInvitation.findMany({
      where: {
        listId,
        claimedAt: null
      }
    })
  ]);

  const memberContacts = members
    .filter((member) => member.userId !== ownerUserId)
    .map((member) => {
      if (!member.user) {
        throw new Error('Expected included user on list member lookup');
      }

      return toMemberResponse({
        ...member,
        user: member.user
      });
    });

  return {
    memberContacts,
    pendingInvitations: invitations.map(toInvitationResponse)
  };
}

export function createListRoutes(deps: ListRoutesDeps = defaultDeps): FastifyPluginAsync {
  return async (app) => {
    app.get('/lists', async (request, reply) => {
      const user = await authenticateRequest(deps.prisma, request, reply);

      if (!user) {
        return;
      }

      const includeArchived = parseIncludeArchived(
        (request.query as { includeArchived?: string | boolean } | undefined)
            ?.includeArchived,
      );

      const lists = await deps.prisma.shoppingList.findMany({
        where: {
          members: {
            some: {
              userId: user.id
            }
          },
          archivedAt: includeArchived ? undefined : null,
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
      const user = await authenticateRequest(deps.prisma, request, reply);

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
          plannedFor: body.plannedFor ?? null,
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

    app.get('/lists/:listId', async (request, reply): Promise<ListDetailResponse | void> => {
      const user = await authenticateRequest(deps.prisma, request, reply);

      if (!user) {
        return;
      }

      const { listId } = request.params as { listId: string };
      const list = await findVisibleList(deps, user.id, listId);

      if (!list) {
        return reply.notFound('List not found');
      }

      const response: ListDetailResponse = {
        list: toListResponse(list)
      };

      if (list.ownerUserId === user.id) {
        response.sharing = await buildOwnerSharingResponse(deps, list.id, user.id);
      }

      return response;
    });

    app.patch('/lists/:listId', async (request, reply) => {
      const user = await authenticateRequest(deps.prisma, request, reply);

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
          name: body.name,
          plannedFor: body.plannedFor ?? null,
        }
      });

      return {
        list: toListResponse(updatedList)
      };
    });

    app.delete('/lists/:listId', async (request, reply) => {
      const user = await authenticateRequest(deps.prisma, request, reply);

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

    app.post('/lists/:listId/archive', async (request, reply) => {
      const user = await authenticateRequest(deps.prisma, request, reply);

      if (!user) {
        return;
      }

      const { listId } = request.params as { listId: string };
      const list = await findVisibleList(deps, user.id, listId);

      if (!list) {
        return reply.notFound('List not found');
      }

      if (list.ownerUserId !== user.id) {
        return reply.forbidden('Only the owner can archive this list');
      }

      const archivedList = await deps.prisma.shoppingList.update({
        where: {
          id: list.id,
        },
        data: {
          archivedAt: new Date(),
          archivedByUserId: user.id,
        },
      });

      return {
        list: toListResponse(archivedList),
      };
    });

    app.post('/lists/:listId/restore', async (request, reply) => {
      const user = await authenticateRequest(deps.prisma, request, reply);

      if (!user) {
        return;
      }

      const { listId } = request.params as { listId: string };
      const list = await findVisibleList(deps, user.id, listId);

      if (!list) {
        return reply.notFound('List not found');
      }

      if (list.ownerUserId !== user.id) {
        return reply.forbidden('Only the owner can restore this list');
      }

      const restoredList = await deps.prisma.shoppingList.update({
        where: {
          id: list.id,
        },
        data: {
          archivedAt: null,
          archivedByUserId: null,
        },
      });

      return {
        list: toListResponse(restoredList),
      };
    });

    app.post('/lists/:listId/members', async (request, reply) => {
      const user = await authenticateRequest(deps.prisma, request, reply);

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

      const normalizedEmail = normalizeEmail(body.email);
      const invitedUser = await deps.prisma.user.findUnique({
        where: {
          email: normalizedEmail
        }
      });

      if (!invitedUser) {
        const existingInvitation = await deps.prisma.listInvitation.findUnique({
          where: {
            listId_email: {
              listId,
              email: normalizedEmail
            }
          }
        });

        if (existingInvitation) {
          return reply.conflict('Invitation is already pending for this email');
        }

        const invitation = await deps.prisma.listInvitation.create({
          data: {
            listId,
            email: normalizedEmail,
            role: 'editor',
            invitedByUserId: user.id
          }
        });

        return reply.code(202).send({
          invitation: toInvitationResponse(invitation)
        });
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

      if (!member.user) {
        throw new Error('Expected included user on list member create');
      }

      const memberWithUser = {
        ...member,
        user: member.user
      };

      return reply.code(201).send({
        member: toMemberResponse(memberWithUser)
      });
    });

    app.delete('/lists/:listId/members/:userId', async (request, reply) => {
      const user = await authenticateRequest(deps.prisma, request, reply);

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
