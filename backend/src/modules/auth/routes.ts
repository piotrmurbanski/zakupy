import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';

import { prisma } from '../../lib/prisma.js';
import type { AuthPrisma, UserRecord } from '../../lib/types.js';
import { toUserResponse } from './utils.js';
import {
  AUTH_CODE_MAX_ATTEMPTS,
  AUTH_CODE_RESEND_WINDOW_SECONDS,
  authenticateRequest,
  deriveDisplayName,
  generateOneTimeCode,
  generateSessionToken,
  getCodeExpiryDate,
  getSessionExpiryDate,
  hashSecret,
  normalizeEmail
} from './session.js';

type AuthRoutesDeps = {
  prisma: Pick<AuthPrisma, 'authCode' | 'authSession' | 'listInvitation' | 'listMember' | 'user'>;
  now: () => Date;
  sendAuthCode: (params: { email: string; code: string }) => Promise<void>;
};

const emailSchema = z.string().trim().email().transform((value) => value.toLowerCase());

const requestCodeBodySchema = z.object({
  email: emailSchema,
  displayName: z.string().trim().min(2).max(50).optional()
});

const verifyCodeBodySchema = z.object({
  email: emailSchema,
  code: z.string().trim().regex(/^\d{6}$/),
  displayName: z.string().trim().min(2).max(50).optional()
});

const defaultDeps: AuthRoutesDeps = {
  prisma: prisma as unknown as AuthRoutesDeps['prisma'],
  now: () => new Date(),
  sendAuthCode: async ({ email, code }) => {
    console.info(`[auth] Sign-in code for ${email}: ${code}`);
  }
};

function parseBody<T>(schema: z.ZodType<T>, body: unknown) {
  const result = schema.safeParse(body);

  if (!result.success) {
    return null;
  }

  return result.data;
}

async function findLatestActiveCode(deps: AuthRoutesDeps, email: string) {
  return deps.prisma.authCode.findFirst({
    where: {
      email,
      consumedAt: null
    },
    orderBy: {
      createdAt: 'desc'
    }
  });
}

async function claimPendingInvitations(deps: AuthRoutesDeps, user: UserRecord, now: Date) {
  const invitations = await deps.prisma.listInvitation.findMany({
    where: {
      email: user.email,
      claimedAt: null
    }
  });

  for (const invitation of invitations) {
    const existingMembership = await deps.prisma.listMember.findUnique({
      where: {
        listId_userId: {
          listId: invitation.listId,
          userId: user.id
        }
      }
    });

    if (!existingMembership) {
      await deps.prisma.listMember.create({
        data: {
          listId: invitation.listId,
          userId: user.id,
          role: invitation.role
        }
      });
    }

    await deps.prisma.listInvitation.update({
      where: {
        id: invitation.id
      },
      data: {
        claimedAt: now,
        claimedByUserId: user.id
      }
    });
  }
}

export function createAuthRoutes(deps: AuthRoutesDeps = defaultDeps): FastifyPluginAsync {
  return async (app) => {
    app.post('/auth/request-code', async (request, reply) => {
      const body = parseBody(requestCodeBodySchema, request.body);

      if (!body) {
        return reply.badRequest('Invalid request body');
      }

      const email = normalizeEmail(body.email);
      const now = deps.now();
      const latestCode = await findLatestActiveCode(deps, email);

      if (latestCode && now.getTime() - latestCode.createdAt.getTime() < AUTH_CODE_RESEND_WINDOW_SECONDS * 1000) {
        return reply.tooManyRequests('Please wait before requesting another code');
      }

      const code = generateOneTimeCode();

      await deps.prisma.authCode.create({
        data: {
          email,
          codeHash: hashSecret(code),
          expiresAt: getCodeExpiryDate(now)
        }
      });

      await deps.sendAuthCode({
        email,
        code
      });

      return reply.code(202).send({
        status: 'code_sent'
      });
    });

    app.post('/auth/verify-code', async (request, reply) => {
      const body = parseBody(verifyCodeBodySchema, request.body);

      if (!body) {
        return reply.badRequest('Invalid request body');
      }

      const email = normalizeEmail(body.email);
      const now = deps.now();
      const authCode = await findLatestActiveCode(deps, email);

      if (!authCode) {
        return reply.unauthorized('Invalid email or code');
      }

      if (authCode.expiresAt.getTime() <= now.getTime()) {
        return reply.unauthorized('Code expired');
      }

      if (authCode.attemptCount >= AUTH_CODE_MAX_ATTEMPTS) {
        return reply.tooManyRequests('Too many invalid attempts');
      }

      if (authCode.codeHash !== hashSecret(body.code)) {
        await deps.prisma.authCode.update({
          where: {
            id: authCode.id
          },
          data: {
            attemptCount: authCode.attemptCount + 1
          }
        });

        return reply.unauthorized('Invalid email or code');
      }

      await deps.prisma.authCode.update({
        where: {
          id: authCode.id
        },
        data: {
          consumedAt: now
        }
      });

      let user = await deps.prisma.user.findUnique({
        where: {
          email
        }
      });

      if (!user) {
        user = await deps.prisma.user.create({
          data: {
            email,
            displayName: body.displayName?.trim() || deriveDisplayName(email)
          }
        });
      }

      await claimPendingInvitations(deps, user, now);

      const sessionToken = generateSessionToken();

      await deps.prisma.authSession.create({
        data: {
          userId: user.id,
          tokenHash: hashSecret(sessionToken),
          expiresAt: getSessionExpiryDate(now)
        }
      });

      return {
        sessionToken,
        user: toUserResponse(user)
      };
    });

    app.post('/auth/logout', async (request, reply) => {
      const token = request.headers.authorization?.replace(/^Bearer\s+/i, '').trim();

      if (!token) {
        return reply.unauthorized('Missing session token');
      }

      const session = await deps.prisma.authSession.findFirst({
        where: {
          tokenHash: hashSecret(token),
          revokedAt: null
        }
      });

      if (!session) {
        return reply.unauthorized('Invalid session');
      }

      await deps.prisma.authSession.update({
        where: {
          id: session.id
        },
        data: {
          revokedAt: deps.now()
        }
      });

      return {
        status: 'logged_out'
      };
    });

    app.get('/auth/me', async (request, reply) => {
      const user = await authenticateRequest(deps.prisma, request, reply);

      if (!user) {
        return;
      }

      return {
        user: toUserResponse(user)
      };
    });
  };
}

export const authRoutes = createAuthRoutes();
