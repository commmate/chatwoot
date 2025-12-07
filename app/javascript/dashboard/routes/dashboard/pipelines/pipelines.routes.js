import { frontendURL } from 'dashboard/helper/URLHelper';

const PipelineBoard = () => import('./PipelineBoard.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/pipelines/:pipelineId'),
      name: 'pipeline_board',
      component: PipelineBoard,
      meta: {
        permissions: ['administrator', 'agent'],
      },
    },
  ],
};

