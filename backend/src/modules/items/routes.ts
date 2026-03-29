import type { FastifyPluginAsync } from 'fastify';

export const itemRoutes: FastifyPluginAsync = async (app) => {
  app.get('/lists/:listId/items', async () => {
    return {
      items: []
    };
  });
};
