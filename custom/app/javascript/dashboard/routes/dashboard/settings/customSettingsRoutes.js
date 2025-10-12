// Custom settings routes for CommMate
// These routes are injected into the main settings routes

import pipelineSettings from './pipelines/pipelines.routes';

export const customSettingsRoutes = [
  ...pipelineSettings.routes,
];

export default {
  routes: customSettingsRoutes,
};

