// Custom routes for CommMate extensions
// This file registers all custom routes

import pipelineRoutes from './dashboard/pipelines/pipelines.routes';

// Export all custom routes  
export const customRoutes = [
  ...pipelineRoutes.routes,
];

export default {
  routes: customRoutes,
};

