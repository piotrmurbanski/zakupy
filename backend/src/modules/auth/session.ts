import crypto from 'node:crypto';

import type { FastifyReply, FastifyRequest } from 'fastify';

import type { UserRecord } from '../../lib/types.js';

export const AUTH_CODE_TTL_MINUTES = 10;
export const AUTH_SESSION_TTL_DAYS = 90;
export const AUTH_CODE_MAX_ATTEMPTS = 5;
export const AUTH_CODE_RESEND_WINDOW_SECONDS = 60;

export function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

export function hashSecret(value: string) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

export function generateOneTimeCode() {
  return crypto.randomInt(0, 1_000_000).toString().padStart(6, '0');
}

export function generateSessionToken() {
  return crypto.randomBytes(24).toString('hex');
}

export function getCodeExpiryDate(from = new Date()) {
  return new Date(from.getTime() + AUTH_CODE_TTL_MINUTES * 60_000);
}

export function getSessionExpiryDate(from = new Date()) {
  return new Date(from.getTime() + AUTH_SESSION_TTL_DAYS * 24 * 60 * 60_000);
}

export function deriveDisplayName(email: string) {
  const localPart = normalizeEmail(email).split('@')[0] ?? 'user';
  return localPart.slice(0, 50) || 'User';
}

function readBearerToken(request: FastifyRequest) {
  const header = request.headers.authorization;

  if (!header) {
    return null;
  }

  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token?.trim()) {
    return null;
  }

  return token.trim();
}

type SessionAuthStore = {
  authSession: {
    findFirst(args: {
      where: {
        tokenHash?: string;
        revokedAt?: null;
      };
      include?: {
        user?: boolean;
      };
    }): Promise<
      | ({
          id: string;
          expiresAt: Date;
          user?: UserRecord;
        } & Record<string, unknown>)
      | null
    >;
    update(args: {
      where: {
        id: string;
      };
      data: {
        lastUsedAt?: Date;
      };
    }): Promise<unknown>;
  };
  user: {
    findUnique(args: {
      where: {
        id?: string;
        email?: string;
      };
    }): Promise<UserRecord | null>;
  };
};

export async function authenticateRequest(
  prisma: SessionAuthStore,
  request: FastifyRequest,
  reply: FastifyReply
): Promise<UserRecord | null> {
  const token = readBearerToken(request);

  if (!token) {
    reply.unauthorized('Missing session token');
    return null;
  }

  const session = await prisma.authSession.findFirst({
    where: {
      tokenHash: hashSecret(token),
      revokedAt: null
    },
    include: {
      user: true
    }
  });

  if (!session?.user || session.expiresAt.getTime() <= Date.now()) {
    reply.unauthorized('Invalid session');
    return null;
  }

  await prisma.authSession.update({
    where: {
      id: session.id
    },
    data: {
      lastUsedAt: new Date()
    }
  });

  return session.user;
}
