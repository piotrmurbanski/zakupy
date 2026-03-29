import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import sensible from '@fastify/sensible';

import { env } from './config/env.js';
import { authRoutes } from './modules/auth/routes.js';
import { healthRoutes } from './modules/health/routes.js';
import { itemRoutes } from './modules/items/routes.js';
import { listRoutes } from './modules/lists/routes.js';

export async function buildApp() {
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

  await app.register(healthRoutes);
  await app.register(authRoutes);
  await app.register(listRoutes);
  await app.register(itemRoutes);

  return app;
}
