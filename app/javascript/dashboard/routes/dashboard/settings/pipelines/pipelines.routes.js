import { frontendURL } from 'dashboard/helper/URLHelper';
import SettingsWrapper from 'dashboard/routes/dashboard/settings/SettingsWrapper.vue';
import SettingsContent from 'dashboard/routes/dashboard/settings/Wrapper.vue';

const PipelinesList = () => import('./Index.vue');
const PipelineEditor = () => import('./PipelineEditor.vue');

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
    {
      path: frontendURL('accounts/:accountId/settings/pipelines'),
      component: SettingsContent,
      props: () => ({
        headerTitle: 'PIPELINES.HEADER',
        icon: 'i-lucide-git-branch',
        showBackButton: true,
      }),
      children: [
        {
          path: 'new',
          name: 'pipelines_new',
          component: PipelineEditor,
          meta: {
            permissions: ['administrator'],
          },
        },
        {
          path: ':pipelineId/edit',
          name: 'pipelines_edit',
          component: PipelineEditor,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};

