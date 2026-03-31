import argon2 from 'argon2';
import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';

import { toUserResponse } from './utils.js';

export const authRoutes: FastifyPluginAsync = async (app) => {
  const credentialsSchema = z.object({
    email: z.string().trim().email().transform((value) => value.toLowerCase()),
    password: z.string().min(8).max(128)
  });

  const registerBodySchema = credentialsSchema.extend({
    displayName: z.string().trim().min(2).max(50)
  });

  app.post('/auth/register', async (request, reply) => {
    const body = registerBodySchema.parse(request.body);

    const existingUser = await app.prisma.user.findUnique({
      where: {
        email: body.email
      }
    });

    if (existingUser) {
      return reply.conflict('User with this email already exists');
    }

    const passwordHash = await argon2.hash(body.password, {
      type: argon2.argon2id
    });

    const user = await app.prisma.user.create({
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
    const body = credentialsSchema.parse(request.body);

    const user = await app.prisma.user.findUnique({
      where: {
        email: body.email
      }
    });

    if (!user) {
      return reply.unauthorized('Invalid email or password');
    }

    const passwordValid = await argon2.verify(user.passwordHash, body.password);

    if (!passwordValid) {
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

  app.get('/auth/me', async (request, reply) => {
    await request.jwtVerify();

    const payload =
      request.user && typeof request.user === 'object' && !Buffer.isBuffer(request.user)
        ? request.user
        : null;
    const userId = payload && 'sub' in payload && typeof payload.sub === 'string' ? payload.sub : null;

    if (!userId) {
      return reply.unauthorized('Invalid token payload');
    }

    const user = await app.prisma.user.findUnique({
      where: {
        id: userId
      }
    });

    if (!user) {
      return reply.unauthorized('User not found');
    }

    return {
      user: toUserResponse(user)
    };
  });
};
