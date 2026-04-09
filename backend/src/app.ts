import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import sensible from '@fastify/sensible';

import { env } from './config/env.js';
import { prisma } from './lib/prisma.js';
import type { AuthPrisma } from './lib/types.js';
import { authRoutes } from './modules/auth/routes.js';
import { healthRoutes } from './modules/health/routes.js';
import { invitationRoutes } from './modules/invitations/routes.js';
import { itemRoutes } from './modules/items/routes.js';
import { listRoutes } from './modules/lists/routes.js';

type BuildAppOptions = {
  prisma?: AuthPrisma;
};

export async function buildApp(options: BuildAppOptions = {}) {
  const app = Fastify({
    logger: true
  });

  await app.register(cors, {
    origin: true
  });

  await app.register(sensible);
  await app.register(jwt, {
    secret: env.JWT_SECRET
  });
  app.decorate('prisma', (options.prisma ?? prisma) as AuthPrisma);

  await app.register(healthRoutes);
  await app.register(authRoutes);
  await app.register(listRoutes);
  await app.register(invitationRoutes);
  await app.register(itemRoutes);

  return app;
}
