import type { FastifyPluginAsync } from 'fastify';

import { prisma } from '../../lib/prisma.js';
import type { InvitationRecord, UserRecord } from '../../lib/types.js';
import { authenticateRequest } from '../auth/session.js';

type InvitationRecordWithRelations = InvitationRecord & {
  list?: {
    id: string;
    name: string;
  };
  invitedByUser?: Pick<UserRecord, 'id' | 'email' | 'displayName'>;
};

type InvitationRepository = {
  findMany(args: {
    where: {
      email?: string;
      claimedAt?: null;
    };
    include?: {
      list?: boolean;
      invitedByUser?: boolean;
    };
  }): Promise<InvitationRecordWithRelations[]>;
  findFirst(args: {
    where: {
      id?: string;
      email?: string;
      claimedAt?: null;
    };
    include?: {
      list?: boolean;
      invitedByUser?: boolean;
    };
  }): Promise<InvitationRecordWithRelations | null>;
  update(args: {
    where: {
      id: string;
    };
    data: {
      claimedAt?: Date;
      claimedByUserId?: string;
    };
  }): Promise<InvitationRecord>;
};

type InvitationRoutesDeps = {
  prisma: {
    user: {
      findUnique(args: {
        where: {
          id?: string;
          email?: string;
        };
      }): Promise<UserRecord | null>;
    };
    authSession: {
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
    listInvitation: InvitationRepository;
    listMember: {
      findUnique(args: {
        where: {
          listId_userId: {
            listId: string;
            userId: string;
          };
        };
      }): Promise<unknown | null>;
      create(args: {
        data: {
          listId: string;
          userId: string;
          role: 'owner' | 'editor';
        };
      }): Promise<unknown>;
    };
  };
  now: () => Date;
};

type InvitationResponse = {
  id: string;
  listId: string;
  listName: string;
  email: string;
  role: string;
  status: 'pending';
  invitedByUser: {
    id: string;
    email: string;
    displayName: string;
  };
  createdAt: Date;
  updatedAt: Date;
};

const defaultDeps: InvitationRoutesDeps = {
  prisma: prisma as unknown as InvitationRoutesDeps['prisma'],
  now: () => new Date(),
};

function toInvitationResponse(
  invitation: InvitationRecordWithRelations,
): InvitationResponse {
  if (!invitation.list || !invitation.invitedByUser) {
    throw new Error('Expected invitation relations to be loaded');
  }

  return {
    id: invitation.id,
    listId: invitation.listId,
    listName: invitation.list.name,
    email: invitation.email,
    role: invitation.role,
    status: 'pending',
    invitedByUser: {
      id: invitation.invitedByUser.id,
      email: invitation.invitedByUser.email,
      displayName: invitation.invitedByUser.displayName,
    },
    createdAt: invitation.createdAt,
    updatedAt: invitation.updatedAt,
  };
}

export function createInvitationRoutes(
  deps: InvitationRoutesDeps = defaultDeps,
): FastifyPluginAsync {
  return async (app) => {
    app.get('/invitations', async (request, reply) => {
      const user = await authenticateRequest(deps.prisma, request, reply);

      if (!user) {
        return;
      }

      const invitations = await deps.prisma.listInvitation.findMany({
        where: {
          email: user.email,
          claimedAt: null,
        },
        include: {
          list: true,
          invitedByUser: true,
        },
      });

      return {
        items: invitations.map(toInvitationResponse),
      };
    });

    app.post('/invitations/:invitationId/accept', async (request, reply) => {
      const user = await authenticateRequest(deps.prisma, request, reply);

      if (!user) {
        return;
      }

      const { invitationId } = request.params as { invitationId: string };
      const invitation = await deps.prisma.listInvitation.findFirst({
        where: {
          id: invitationId,
          email: user.email,
          claimedAt: null,
        },
        include: {
          list: true,
          invitedByUser: true,
        },
      });

      if (!invitation) {
        return reply.notFound('Invitation not found');
      }

      const existingMembership = await deps.prisma.listMember.findUnique({
        where: {
          listId_userId: {
            listId: invitation.listId,
            userId: user.id,
          },
        },
      });

      if (!existingMembership) {
        await deps.prisma.listMember.create({
          data: {
            listId: invitation.listId,
            userId: user.id,
            role: invitation.role,
          },
        });
      }

      await deps.prisma.listInvitation.update({
        where: {
          id: invitation.id,
        },
        data: {
          claimedAt: deps.now(),
          claimedByUserId: user.id,
        },
      });

      return {
        invitation: toInvitationResponse(invitation),
        status: 'accepted',
      };
    });
  };
}

export const invitationRoutes = createInvitationRoutes();
