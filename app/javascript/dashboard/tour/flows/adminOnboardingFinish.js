/**
 * Admin Onboarding Flow: Finish Setup
 *
 * Final onboarding flow that shows on the finish/success page
 * and guides the user to start using their inbox.
 */

import { SELECTORS } from '../selectors';

export default {
  id: 'adminOnboardingFinish',
  role: 'admin',
  allowSkip: true,

  // Only run for the first inbox setup; don't re-run when the user adds more inboxes later.
  prerequisites: context => (context.inboxes || []).length <= 1,

  // Only run on the inbox finish page
  routes: ['settings_inbox_finish'],

  steps: [
    {
      id: 'finish-congrats',
      popover: {
        titleKey: 'TOUR.ONBOARDING.FINISH.COMPLETE.TITLE',
        descriptionKey: 'TOUR.ONBOARDING.FINISH.COMPLETE.DESCRIPTION',
        side: 'bottom',
        align: 'center',
      },
    },
    {
      id: 'finish-bring-me-there',
      element: SELECTORS.finishBringMeThere,
      waitForElement: true,
      allowInteraction: true,
      completeFlowOnElementClick: true,
      popover: {
        titleKey: 'TOUR.ONBOARDING.FINISH.START_CHATTING.TITLE',
        descriptionKey: 'TOUR.ONBOARDING.FINISH.START_CHATTING.DESCRIPTION',
        side: 'top',
        align: 'start',
      },
    },
  ],
};
