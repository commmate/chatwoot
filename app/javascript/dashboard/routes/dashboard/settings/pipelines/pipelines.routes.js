import { frontendURL } from 'dashboard/helper/URLHelper';
import SettingsWrapper from 'dashboard/routes/dashboard/settings/SettingsWrapper.vue';

const PipelinesList = () => import('./Index.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/pipelines'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'pipelines_list',
          component: PipelinesList,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
