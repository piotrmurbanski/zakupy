import type { FastifyPluginAsync } from 'fastify';

export const listRoutes: FastifyPluginAsync = async (app) => {
  app.get('/lists', async () => {
    return {
      items: []
    };
  });
};
