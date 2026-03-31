import type { AuthPrisma } from '../lib/types.js';

declare module 'fastify' {
  interface FastifyInstance {
    prisma: AuthPrisma;
  }
}
