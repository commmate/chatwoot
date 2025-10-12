// Custom routes for CommMate extensions
// This file registers all custom routes

import kanbanRoutes from './dashboard/kanban/kanban.routes';

// Export all custom routes
export const customRoutes = [
  ...kanbanRoutes.routes,
];

export default {
  routes: customRoutes,
};

