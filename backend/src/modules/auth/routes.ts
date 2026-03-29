import argon2 from 'argon2';
import type { FastifyPluginAsync } from 'fastify';
import { z } from 'zod';

import { prisma } from '../../lib/prisma.js';

export const authRoutes: FastifyPluginAsync = async (app) => {
  const registerBodySchema = z.object({
    email: z.string().trim().email().transform((value) => value.toLowerCase()),
    password: z.string().min(8).max(128),
    displayName: z.string().trim().min(2).max(50)
  });

  app.post('/auth/register', async (request, reply) => {
    const body = registerBodySchema.parse(request.body);

    const existingUser = await prisma.user.findUnique({
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

    const user = await prisma.user.create({
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
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt
      }
    });
  });

  app.get('/auth/me', async () => {
    return {
      message: 'TODO: implement auth'
    };
  });
};
