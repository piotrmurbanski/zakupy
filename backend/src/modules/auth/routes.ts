import argon2 from 'argon2';
import type { PrismaClient } from '@prisma/client';
import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';

import { prisma } from '../../lib/prisma.js';
import { toUserResponse } from './utils.js';

type AuthRoutesDeps = {
  prisma: Pick<PrismaClient, 'user'>;
  hashPassword: (password: string) => Promise<string>;
  verifyPassword: (hash: string, password: string) => Promise<boolean>;
};

type JwtUserPayload = {
  sub: string;
  email: string;
};

const loginBodySchema = z.object({
  email: z.string().trim().email().transform((value) => value.toLowerCase()),
  password: z.string().min(1).max(128)
});

const registerBodySchema = z.object({
  email: z.string().trim().email().transform((value) => value.toLowerCase()),
  password: z.string().min(8).max(128),
  displayName: z.string().trim().min(2).max(50)
});

const defaultDeps: AuthRoutesDeps = {
  prisma,
  hashPassword: async (password) =>
    argon2.hash(password, {
      type: argon2.argon2id
    }),
  verifyPassword: async (hash, password) => argon2.verify(hash, password)
};

function parseBody<T>(schema: z.ZodType<T>, body: unknown) {
  const result = schema.safeParse(body);

  if (!result.success) {
    return null;
  }

  return result.data;
}

async function authenticateUser(deps: AuthRoutesDeps, email: string, password: string) {
  const user = await deps.prisma.user.findUnique({
    where: {
      email
    }
  });

  if (!user) {
    return null;
  }

  const passwordMatches = await deps.verifyPassword(user.passwordHash, password);

  if (!passwordMatches) {
    return null;
  }

  return user;
}

export function createAuthRoutes(deps: AuthRoutesDeps = defaultDeps): FastifyPluginAsync {
  return async (app) => {
    app.post('/auth/register', async (request, reply) => {
      const body = parseBody(registerBodySchema, request.body);

      if (!body) {
        return reply.badRequest('Invalid request body');
      }

      const existingUser = await deps.prisma.user.findUnique({
        where: {
          email: body.email
        }
      });

      if (existingUser) {
        return reply.conflict('User with this email already exists');
      }

      const passwordHash = await deps.hashPassword(body.password);

      const user = await deps.prisma.user.create({
        data: {
          email: body.email,
          passwordHash,
          displayName: body.displayName
        }
      });

      const accessToken = await reply.jwtSign({
        sub: user.id,
        email: user.email
      });

      return reply.code(201).send({
        accessToken,
        user: toUserResponse(user)
      });
    });

    app.post('/auth/login', async (request, reply) => {
      const body = parseBody(loginBodySchema, request.body);

      if (!body) {
        return reply.badRequest('Invalid request body');
      }

      const user = await authenticateUser(deps, body.email, body.password);

      if (!user) {
        return reply.unauthorized('Invalid email or password');
      }

      const accessToken = await reply.jwtSign({
        sub: user.id,
        email: user.email
      });

      return {
        accessToken,
        user: toUserResponse(user)
      };
    });

    app.get('/auth/me', async (request) => {
      const payload = await request.jwtVerify<JwtUserPayload>();
      const user = await deps.prisma.user.findUnique({
        where: {
          id: payload.sub
        }
      });

      if (!user) {
        return request.server.httpErrors.unauthorized('User not found');
      }

      return {
        user: toUserResponse(user)
      };
    });
  };
}

export const authRoutes = createAuthRoutes();
