/**
 * Admin Onboarding Flow: Evolution QR Setup
 *
 * Guides admins through connecting their WhatsApp via Evolution API QR code.
 * This is the first onboarding flow, triggered on the Evolution inbox creation page.
 */

import { SELECTORS } from '../selectors';

export default {
  id: 'adminOnboardingEvolutionQr',
  role: 'admin',
  allowSkip: true,

  // Only run once per account: if the account already has any inboxes,
  // we assume onboarding has happened and we don't re-run it when adding more inboxes.
  prerequisites: context => (context.inboxes || []).length === 0,

  // Only run on Evolution WhatsApp setup page
  routes: [
    {
      name: 'settings_inboxes_page_channel',
      params: { sub_page: 'evolution' },
    },
  ],

  // Start route for restart functionality
  startRoute: {
    name: 'settings_inboxes_page_channel',
    params: { sub_page: 'evolution' },
  },

  steps: [
    {
      id: 'evolution-welcome',
      element: SELECTORS.evolutionInboxName,
      waitForElement: true,
      popover: {
        titleKey: 'TOUR.ONBOARDING.EVOLUTION_QR.WELCOME.TITLE',
        descriptionKey: 'TOUR.ONBOARDING.EVOLUTION_QR.WELCOME.DESCRIPTION',
        side: 'bottom',
        align: 'start',
      },
    },
    {
      id: 'evolution-load-qr',
      element: SELECTORS.evolutionLoadQR,
      waitForElement: true,
      allowInteraction: true,
      popover: {
        titleKey: 'TOUR.ONBOARDING.EVOLUTION_QR.LOAD_QR.TITLE',
        descriptionKey: 'TOUR.ONBOARDING.EVOLUTION_QR.LOAD_QR.DESCRIPTION',
        side: 'bottom',
        align: 'start',
      },
    },
    {
      id: 'evolution-qr-code',
      element: SELECTORS.evolutionQRCode,
      waitForElement: true,
      popover: {
        titleKey: 'TOUR.ONBOARDING.EVOLUTION_QR.SCAN_QR.TITLE',
        descriptionKey: 'TOUR.ONBOARDING.EVOLUTION_QR.SCAN_QR.DESCRIPTION',
        side: 'left',
        align: 'center',
        mobileSide: 'bottom',
      },
    },
    {
      id: 'evolution-continue',
      element: SELECTORS.evolutionContinue,
      waitForElement: true,
      allowInteraction: true,
      completeFlowOnElementClick: true,
      popover: {
        titleKey: 'TOUR.ONBOARDING.EVOLUTION_QR.CONTINUE.TITLE',
        descriptionKey: 'TOUR.ONBOARDING.EVOLUTION_QR.CONTINUE.DESCRIPTION',
        side: 'top',
        align: 'start',
      },
    },
  ],
};
