import { frontendURL } from 'dashboard/helper/URLHelper';

const KanbanBoard = () => import('./Index.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/kanban'),
      name: 'kanban_board',
      meta: {
        permissions: ['administrator', 'agent', 'conversation_manage'],
      },
      component: KanbanBoard,
    },
  ],
};

