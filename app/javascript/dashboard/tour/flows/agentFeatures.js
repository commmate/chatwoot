/**
 * Agent Features Flow
 *
 * Tour of CommMate features for agents (non-admins).
 * Triggered on first visit to the main conversations page (home).
 * Steps are filtered based on agent's custom permissions.
 */

import { SELECTORS } from '../selectors';
import { TOUR_PERMISSIONS, TOUR_FEATURE_FLAGS } from '../permissions';

export default {
  id: 'agentFeatures',
  role: 'agent',
  allowSkip: true,

  // Trigger on main conversations page
  routes: ['home', 'inbox_dashboard'],

  // Start route for restart functionality
  startRoute: { name: 'home' },

  steps: [
    // --- Welcome ---
    {
      id: 'agent-welcome',
      popover: {
        titleKey: 'TOUR.AGENT_FEATURES.WELCOME.TITLE',
        descriptionKey: 'TOUR.AGENT_FEATURES.WELCOME.DESCRIPTION',
        side: 'bottom',
        align: 'center',
      },
    },

    // --- Conversations ---
    {
      id: 'sidebar-conversations',
      element: SELECTORS.sidebarConversations,
      waitForElement: true,
      autoNavigateOnNext: true,
      waitForUrlIncludes: '/dashboard',
      navigateBeforeHighlightDesktop: { name: 'home' },
      popover: {
        titleKey: 'TOUR.AGENT_FEATURES.CONVERSATIONS.TITLE',
        descriptionKey: 'TOUR.AGENT_FEATURES.CONVERSATIONS.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
    },

    // --- Contacts ---
    {
      id: 'sidebar-contacts',
      element: SELECTORS.sidebarContacts,
      waitForElement: true,
      autoNavigateOnNext: true,
      waitForUrlIncludes: '/contacts',
      popover: {
        titleKey: 'TOUR.AGENT_FEATURES.CONTACTS.TITLE',
        descriptionKey: 'TOUR.AGENT_FEATURES.CONTACTS.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
    },

    // --- Reports (if accessible) ---
    {
      id: 'sidebar-reports',
      element: SELECTORS.sidebarReports,
      waitForElement: true,
      autoNavigateOnNext: true,
      waitForUrlIncludes: '/reports',
      popover: {
        titleKey: 'TOUR.AGENT_FEATURES.REPORTS.TITLE',
        descriptionKey: 'TOUR.AGENT_FEATURES.REPORTS.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
      requiredPermissions: TOUR_PERMISSIONS.REPORTS_VIEW,
      featureFlag: TOUR_FEATURE_FLAGS.REPORTS,
    },

    // --- Settings (to expand menu for canned responses) ---
    {
      id: 'sidebar-settings',
      element: SELECTORS.sidebarSettings,
      waitForElement: true,
      autoNavigateOnNext: true,
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.SETTINGS.TITLE',
        descriptionKey: 'TOUR.ADMIN_FEATURES.SETTINGS.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
    },

    // --- Saved Replies (under Settings) ---
    {
      id: 'canned-responses',
      element: SELECTORS.settingsCannedResponses,
      waitForElement: true,
      autoNavigateOnNext: true,
      waitForUrlIncludes: '/settings/canned-responses',
      popover: {
        titleKey: 'TOUR.AGENT_FEATURES.CANNED_RESPONSES.TITLE',
        descriptionKey: 'TOUR.AGENT_FEATURES.CANNED_RESPONSES.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
      featureFlag: TOUR_FEATURE_FLAGS.CANNED_RESPONSES,
    },

    // --- Macros (if accessible) ---
    {
      id: 'settings-macros',
      element: SELECTORS.settingsMacros,
      waitForElement: true,
      autoNavigateOnNext: true,
      waitForUrlIncludes: '/settings/macros',
      popover: {
        titleKey: 'TOUR.ADMIN_FEATURES.MACROS.TITLE',
        descriptionKey: 'TOUR.ADMIN_FEATURES.MACROS.DESCRIPTION',
        side: 'right',
        align: 'start',
      },
      requiredPermissions: TOUR_PERMISSIONS.MACROS_MANAGE,
      featureFlag: TOUR_FEATURE_FLAGS.MACROS,
    },

    // --- Tour Complete ---
    {
      id: 'agent-tour-complete',
      popover: {
        titleKey: 'TOUR.AGENT_FEATURES.COMPLETE.TITLE',
        descriptionKey: 'TOUR.AGENT_FEATURES.COMPLETE.DESCRIPTION',
        side: 'bottom',
        align: 'center',
      },
    },
  ],
};
