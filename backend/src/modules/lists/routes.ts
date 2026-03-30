import type { FastifyPluginAsync } from 'fastify';

export const listRoutes: FastifyPluginAsync = async (app) => {
  app.get('/lists', {
    preHandler: async (request) => {
      await request.jwtVerify();
    }
  }, async () => {
    return {
      items: []
    };
  });
};
