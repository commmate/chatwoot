/**
 * Admin Onboarding Flow: Add Agents
 *
 * Guides admins through adding agents to their newly created inbox.
 * This flow is triggered after the Evolution QR flow when the user reaches
 * the add agents page.
 */

import { SELECTORS } from '../selectors';
import { TOUR_PERMISSIONS } from '../permissions';

export default {
  id: 'adminOnboardingAddAgents',
  role: 'admin',
  allowSkip: true,

  // Only run for the first inbox setup (after first inbox creation the count is typically 1).
  prerequisites: context => (context.inboxes || []).length <= 1,

  // Only run on the add agents page
  routes: ['settings_inboxes_add_agents'],

  steps: [
    {
      id: 'add-agents-intro',
      element: SELECTORS.addAgentsMultiselect,
      waitForElement: true,
      popover: {
        titleKey: 'TOUR.ONBOARDING.ADD_AGENTS.INTRO.TITLE',
        descriptionKey: 'TOUR.ONBOARDING.ADD_AGENTS.INTRO.DESCRIPTION',
        side: 'bottom',
        align: 'start',
      },
      requiredPermissions: TOUR_PERMISSIONS.AGENTS_MANAGE,
    },
    {
      id: 'onboard-new-agent',
      element: SELECTORS.onboardNewAgentBtn,
      waitForElement: true,
      allowInteraction: true,
      popover: {
        titleKey: 'TOUR.ONBOARDING.ADD_AGENTS.ONBOARD_NEW_AGENT.TITLE',
        descriptionKey:
          'TOUR.ONBOARDING.ADD_AGENTS.ONBOARD_NEW_AGENT.DESCRIPTION',
        side: 'bottom',
        align: 'start',
      },
      requiredPermissions: TOUR_PERMISSIONS.AGENTS_MANAGE,
    },
    {
      id: 'add-agents-submit',
      element: SELECTORS.addAgentsSubmit,
      waitForElement: true,
      allowInteraction: true,
      completeFlowOnElementClick: true,
      popover: {
        titleKey: 'TOUR.ONBOARDING.ADD_AGENTS.SUBMIT.TITLE',
        descriptionKey: 'TOUR.ONBOARDING.ADD_AGENTS.SUBMIT.DESCRIPTION',
        side: 'top',
        align: 'start',
      },
    },
  ],
};
