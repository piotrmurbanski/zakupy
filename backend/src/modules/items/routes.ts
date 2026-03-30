import type { FastifyPluginAsync } from 'fastify';

export const itemRoutes: FastifyPluginAsync = async (app) => {
  app.get('/lists/:listId/items', {
    preHandler: async (request) => {
      await request.jwtVerify();
    }
  }, async () => {
    return {
      items: []
    };
  });
};
